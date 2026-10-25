<%@ WebHandler Language="C#" Class="UploadLogHandler" %>

using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Script.Serialization;

public class UploadLogHandler : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentEncoding = System.Text.Encoding.UTF8;
        context.Response.AddHeader("Access-Control-Allow-Origin", "*");
        context.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        context.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

        if (context.Request.HttpMethod == "OPTIONS")
        {
            context.Response.StatusCode = 204;
            return;
        }

        try
        {
            if (context.Request.HttpMethod == "POST")
                AppendLog(context);
            else if (context.Request.HttpMethod == "GET" && context.Request.QueryString["action"] == "download")
                DownloadLogs(context);
            else
                WriteError(context, 405, "Unsupported operation.");
        }
        catch (ArgumentException ex)
        {
            WriteError(context, 400, ex.Message);
        }
        catch (UnauthorizedAccessException ex)
        {
            WriteError(context, 403, ex.Message);
        }
        catch (FileNotFoundException ex)
        {
            WriteError(context, 404, ex.Message);
        }
        catch (Exception ex)
        {
            WriteError(context, 500, ex.Message);
        }
    }

    private static void AppendLog(HttpContext context)
    {
        string jsonBody;
        using (var reader = new StreamReader(context.Request.InputStream))
            jsonBody = reader.ReadToEnd();

        if (string.IsNullOrWhiteSpace(jsonBody))
            throw new ArgumentException("Empty request body");

        var serializer = new JavaScriptSerializer();
        var logEntry = serializer.DeserializeObject(jsonBody) as IDictionary;
        if (logEntry == null || !logEntry.Contains("message") || !logEntry.Contains("timestamp"))
            throw new ArgumentException("Missing required fields: message and/or timestamp");

        string message = Convert.ToString(logEntry["message"]);
        string timestamp = Convert.ToString(logEntry["timestamp"]);
        string userID = logEntry.Contains("userID") ? Convert.ToString(logEntry["userID"]) : "Unknown";
        string logDir = GetLogDirectory(context);
        Directory.CreateDirectory(logDir);

        string logPath = Path.Combine(
            logDir,
            string.Format("Support_Web_{0:yyyyMMdd_HH}.log", DateTime.Now));
        string line = string.Format(
            "[{0}] User ID: {1} {2}{3}",
            timestamp,
            userID,
            message,
            Environment.NewLine);
        File.AppendAllText(logPath, line);

        context.Response.ContentType = "application/json";
        context.Response.Write("{\"status\":\"ok\"}");
    }

    private static void DownloadLogs(HttpContext context)
    {
        ValidateDebugUser(context);

        string logDir = GetLogDirectory(context);
        if (!Directory.Exists(logDir))
            throw new FileNotFoundException("The diagnostic log directory does not exist.");

        string[] files;
        bool latest = string.Equals(
            context.Request.QueryString["latest"],
            "true",
            StringComparison.OrdinalIgnoreCase);

        if (latest)
        {
            var newest = Directory.GetFiles(logDir, "Support_Web_*.log")
                .Select(path => new FileInfo(path))
                .OrderByDescending(file => file.LastWriteTimeUtc)
                .FirstOrDefault();
            if (newest == null)
                throw new FileNotFoundException("No diagnostic log files were found.");
            files = new[] { newest.FullName };
        }
        else
        {
            DateTime selectedDate;
            string dateValue = context.Request.QueryString["date"];
            if (!DateTime.TryParseExact(
                dateValue,
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out selectedDate))
                throw new ArgumentException("A valid date in yyyy-MM-dd format is required.");

            files = Directory.GetFiles(
                logDir,
                string.Format("Support_Web_{0:yyyyMMdd}_*.log", selectedDate));
            if (files.Length == 0)
                throw new FileNotFoundException("No diagnostic logs were found for the selected day.");
        }

        string zipName = latest
            ? string.Format("Support_Web_latest_{0:yyyyMMdd_HHmm}.zip", DateTime.Now)
            : string.Format("Support_Web_{0}.zip", context.Request.QueryString["date"]);

        context.Response.Clear();
        context.Response.ContentType = "application/zip";
        context.Response.AddHeader("Content-Disposition", "attachment; filename=\"" + zipName + "\"");

        using (var archive = new ZipArchive(context.Response.OutputStream, ZipArchiveMode.Create, true))
        {
            foreach (string file in files.OrderBy(path => path))
            {
                var entry = archive.CreateEntry(Path.GetFileName(file), CompressionLevel.Optimal);
                using (var input = File.Open(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (var output = entry.Open())
                    input.CopyTo(output);
            }
        }
    }

    private static void ValidateDebugUser(HttpContext context)
    {
        int userID;
        if (!int.TryParse(context.Request.QueryString["UserID"], out userID))
            throw new UnauthorizedAccessException("A valid user is required.");

        string authorization = context.Request.Headers["Authorization"];
        if (string.IsNullOrWhiteSpace(authorization) || !authorization.StartsWith("Bearer "))
            throw new UnauthorizedAccessException("Authentication is required.");

        var serializer = new JavaScriptSerializer();
        string configPath = context.Server.MapPath("~/config.json");
        if (!File.Exists(configPath))
            throw new UnauthorizedAccessException("Service configuration is unavailable.");

        var config = serializer.DeserializeObject(File.ReadAllText(configPath)) as IDictionary;
        string baseUrl = config != null && config.Contains("INTERFACE_BASE_URL")
            ? Convert.ToString(config["INTERFACE_BASE_URL"])
            : null;
        if (string.IsNullOrWhiteSpace(baseUrl))
            throw new UnauthorizedAccessException("Interface service is not configured.");

        string userInfoUrl = baseUrl.TrimEnd('/') + "/GetUserInfo?UserID=" + userID;
        string response;
        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.Authorization] = authorization;
            client.Headers[HttpRequestHeader.Accept] = "application/json";
            response = client.DownloadString(userInfoUrl);
        }

        var userInfo = serializer.DeserializeObject(response) as IDictionary;
        string mode = userInfo != null && userInfo.Contains("DEBUG_MODE")
            ? Convert.ToString(userInfo["DEBUG_MODE"])
            : "N";
        if (!string.Equals(mode, "T", StringComparison.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException("Diagnostic download is not enabled for this account.");
    }

    private static string GetLogDirectory(HttpContext context)
    {
        string logDir = System.Configuration.ConfigurationManager.AppSettings["LABSAVEDIR"];
        if (!string.IsNullOrWhiteSpace(logDir))
            return logDir;

        string configPath = context.Server.MapPath("~/config.json");
        if (File.Exists(configPath))
        {
            var serializer = new JavaScriptSerializer();
            var config = serializer.DeserializeObject(File.ReadAllText(configPath)) as IDictionary;
            if (config != null && config.Contains("LABSAVEDIR"))
                logDir = Convert.ToString(config["LABSAVEDIR"]);
        }
        return string.IsNullOrWhiteSpace(logDir) ? @"C:\LABSAVE\SUPPORT_WEB_DEV\" : logDir;
    }

    private static void WriteError(HttpContext context, int statusCode, string message)
    {
        context.Response.Clear();
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        context.Response.Write("{\"error\":\"" + HttpUtility.JavaScriptStringEncode(message) + "\"}");
    }

    public bool IsReusable { get { return false; } }
}
