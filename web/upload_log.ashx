<%@ WebHandler Language="C#" Class="UploadLogHandler" %>

using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
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

        WriteZip(context.Response.OutputStream, files.OrderBy(path => path).ToArray());
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

    // Writes standards-compliant ZIP entries using the STORE method. This
    // avoids a System.IO.Compression assembly dependency in ASP.NET dynamic
    // compilation on the current IIS server.
    private static void WriteZip(Stream output, string[] files)
    {
        var records = new System.Collections.Generic.List<ZipRecord>();
        var writer = new BinaryWriter(output, Encoding.UTF8, true);
        uint offset = 0;

        foreach (string path in files)
        {
            var info = new FileInfo(path);
            if (info.Length > UInt32.MaxValue)
                throw new InvalidOperationException("A log file is too large for ZIP download.");

            byte[] name = Encoding.UTF8.GetBytes(Path.GetFileName(path));
            uint size = (uint)info.Length;
            uint crc = CalculateCrc32(path);
            ushort dosTime;
            ushort dosDate;
            GetDosDateTime(info.LastWriteTime, out dosTime, out dosDate);

            records.Add(new ZipRecord {
                Name = name,
                Crc = crc,
                Size = size,
                Offset = offset,
                Time = dosTime,
                Date = dosDate
            });

            writer.Write(0x04034b50u);
            writer.Write((ushort)20);
            writer.Write((ushort)0x0800);
            writer.Write((ushort)0);
            writer.Write(dosTime);
            writer.Write(dosDate);
            writer.Write(crc);
            writer.Write(size);
            writer.Write(size);
            writer.Write((ushort)name.Length);
            writer.Write((ushort)0);
            writer.Write(name);

            using (var input = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                input.CopyTo(output);

            offset += (uint)(30 + name.Length) + size;
        }

        uint centralOffset = offset;
        foreach (ZipRecord record in records)
        {
            writer.Write(0x02014b50u);
            writer.Write((ushort)20);
            writer.Write((ushort)20);
            writer.Write((ushort)0x0800);
            writer.Write((ushort)0);
            writer.Write(record.Time);
            writer.Write(record.Date);
            writer.Write(record.Crc);
            writer.Write(record.Size);
            writer.Write(record.Size);
            writer.Write((ushort)record.Name.Length);
            writer.Write((ushort)0);
            writer.Write((ushort)0);
            writer.Write((ushort)0);
            writer.Write((ushort)0);
            writer.Write(0u);
            writer.Write(record.Offset);
            writer.Write(record.Name);
            offset += (uint)(46 + record.Name.Length);
        }

        uint centralSize = offset - centralOffset;
        writer.Write(0x06054b50u);
        writer.Write((ushort)0);
        writer.Write((ushort)0);
        writer.Write((ushort)records.Count);
        writer.Write((ushort)records.Count);
        writer.Write(centralSize);
        writer.Write(centralOffset);
        writer.Write((ushort)0);
        writer.Flush();
    }

    private static uint CalculateCrc32(string path)
    {
        uint crc = 0xffffffffu;
        using (var input = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            int value;
            while ((value = input.ReadByte()) != -1)
            {
                crc ^= (byte)value;
                for (int bit = 0; bit < 8; bit++)
                    crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320u : crc >> 1;
            }
        }
        return crc ^ 0xffffffffu;
    }

    private static void GetDosDateTime(DateTime value, out ushort time, out ushort date)
    {
        int year = Math.Max(1980, Math.Min(2107, value.Year));
        time = (ushort)((value.Hour << 11) | (value.Minute << 5) | (value.Second / 2));
        date = (ushort)(((year - 1980) << 9) | (value.Month << 5) | value.Day);
    }

    private sealed class ZipRecord
    {
        public byte[] Name;
        public uint Crc;
        public uint Size;
        public uint Offset;
        public ushort Time;
        public ushort Date;
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
