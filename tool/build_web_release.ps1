param([ValidateSet('dev','prod')][string]$Environment='dev',[Parameter(Mandatory=$true)][string]$FlutterPath)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot
Push-Location $project
try {
  $package=[regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*(\S+)').Groups[1].Value
  $version=$package.Replace('+','.')
  $config=Get-Content "config.$Environment.json" -Raw | ConvertFrom-Json
  & $FlutterPath build web --release --no-pub "--base-href=/$Environment/" "--dart-define=BUILD_ENV=$Environment" "--dart-define=APP_BUILD_VERSION=$version" "--dart-define=BASE_URL_AUTH=$($config.AUTH_BASE_URL)" "--dart-define=BASE_URL_DATA=$($config.INTERFACE_BASE_URL)"
  if ($LASTEXITCODE -ne 0) {throw 'Flutter build failed'}
  $config | Add-Member BUILD_VERSION $version -Force
  $config | Add-Member BUILD_TIMESTAMP_UTC ([DateTime]::UtcNow.ToString('o')) -Force
  $config | ConvertTo-Json | Set-Content build/web/config.json -Encoding utf8
  $index=Join-Path $project 'build/web/index.html'
  [IO.File]::WriteAllText($index,([IO.File]::ReadAllText($index).Replace('__APP_VERSION__',$version)))
  $bootstrap=Join-Path $project 'build/web/flutter_bootstrap.js'
  [IO.File]::WriteAllText($bootstrap,([IO.File]::ReadAllText($bootstrap).Replace('__APP_VERSION__',$version)))
  Copy-Item build/web/main.dart.js "build/web/main.$version.dart.js" -Force
  Write-Output "Built $Environment $version with matching footer/config metadata."
} finally {Pop-Location}
