#參考來源->http://blog.danskingdom.com/force-clickonce-applications-to-automatically-update-without-prompting-user-automatically-update-minimumrequiredversion-using-powershell/
 
[Parameter(Position=0, HelpMessage="專案路徑,組態名稱")]
Param([string]$projectDirPath, [string]$configuration)

function CleanExt($text){
    $result = $text -replace $devClickoncePathExt, "" -replace $testClickoncePathExt, "" -replace $devAssemblyTitle, "" -replace $testAssemblyTitle, "" -replace "\(", "" -replace "\)", "" -replace "\%28", "" -replace "\%29", ""
    return $result
}

#$projectDirPath = "D:\Frank_Tseng\Projects\試作程式\ClickOnce\Source\ClickOnce\"
#$configuration = "Debug"

$projectFilePath = (Get-ChildItem -Path $projectDirPath -Filter *.csproj -Recurse).FullName
$appConfigFilePath = (Get-ChildItem -Path $projectDirPath -Filter App.config -Recurse).FullName
$assemblyInfoFilePath = (Get-ChildItem -Path $projectDirPath -Filter AssemblyInfo.cs -Recurse).FullName

if (-not([System.IO.File]::Exists($projectFilePath))) {
    throw "找不到組態檔: '$projectFilePath'" 
}

if (-not([System.IO.File]::Exists($appConfigFilePath))) {
    throw "找不到App.config: '$appConfigFilePath'" 
}

if (-not([System.IO.File]::Exists($assemblyInfoFilePath))) {
    throw "找不到組件資訊檔: '$assemblyInfoFilePath'" 
}

$clickoncePathExt = ""
$assemblyTitle = ""
$devAssemblyTitle = "開發版"
$testAssemblyTitle = "測試版"
$prdAssemblyTitle = "正式版"
$devClickoncePathExt = "_dev"
$testClickoncePathExt = "_test"
$productNameExt = ""

switch($configuration){
    "Debug"   { $clickoncePathExt = $devClickoncePathExt;  $assemblyTitle = $devAssemblyTitle;  $productNameExt = "(" + $devAssemblyTitle + ")";  break }
    "Release" { $clickoncePathExt = "";                    $assemblyTitle = $prdAssemblyTitle;  $productNameExt = "";                             break }
    "Test"    { $clickoncePathExt = $testClickoncePathExt; $assemblyTitle = $testAssemblyTitle; $productNameExt = "(" + $testAssemblyTitle + ")"; break }
    default {throw "組態名稱必須是Debug/Release/Test之一"}
}

#csproj修改開始 
$projectFileText = [System.IO.File]::ReadAllText($projectFilePath)

$minimumRequiredVersionRegex = New-Object System.Text.RegularExpressions.Regex "\<MinimumRequiredVersion\>(?<MinimumRequiredVersion>\d+\.\d+\.\d+\.\d+)\<\/MinimumRequiredVersion\>", SingleLine
$applicationVersionRegex = New-Object System.Text.RegularExpressions.Regex "\<ApplicationVersion\>(?<ApplicationVersion>\d+\.\d+\.\d+\.)\%2a\<\/ApplicationVersion\>", SingleLine
$applicationRevisionRegex = New-Object System.Text.RegularExpressions.Regex "\<ApplicationRevision\>(?<ApplicationRevision>\d+)\<\/ApplicationRevision\>", SingleLine
 
$oldMinimumRequiredVersion = $minimumRequiredVersionRegex.Match($projectFileText).Groups["MinimumRequiredVersion"].Value
if($oldMinimumRequiredVersion.Length -eq 0) {
    throw "未設定 專案屬性>發行>更新>[最小必要版本]"
}

$majorMinorBuild = $applicationVersionRegex.Match($projectFileText).Groups["ApplicationVersion"].Value
$revision = $applicationRevisionRegex.Match($projectFileText).Groups["ApplicationRevision"].Value
$newMinimumRequiredVersion = [string]$majorMinorBuild + $revision

$assemblyNameRegex = New-Object System.Text.RegularExpressions.Regex "\<AssemblyName\>(?<AssemblyName>\S+)\<\/AssemblyName\>", SingleLine
$productNameRegex = New-Object System.Text.RegularExpressions.Regex "\<ProductName\>(?<ProductName>\S+)\<\/ProductName\>", SingleLine
$publishUrlRegex = New-Object System.Text.RegularExpressions.Regex "\<PublishUrl\>(?<PublishUrl>\S+)\<\/PublishUrl\>", SingleLine

$oldAssemblyName = CleanExt($assemblyNameRegex.Match($projectFileText).Groups["AssemblyName"].Value)
$oldProductName = CleanExt($productNameRegex.Match($projectFileText).Groups["ProductName"].Value)
if($oldProductName.Length -eq 0) {
    throw "未設定 專案屬性>發行>選項>[產品名稱]"
}

$oldPublishUrl = $publishUrlRegex.Match($projectFileText).Groups["PublishUrl"].Value
if($oldPublishUrl.Length -eq 0) {
    throw "未設定 專案屬性>發行>[發行資料夾位置]"
}

$oldPublishUrl = CleanExt($oldPublishUrl.Substring(0, $oldPublishUrl.Length -1))

$newAssemblyName = $oldAssemblyName + $clickoncePathExt
$newProductName = $oldProductName + $productNameExt
$newPublishUrl = $oldPublishUrl + $clickoncePathExt + "\"

$projectFileText = $minimumRequiredVersionRegex.Replace($projectFileText, "<MinimumRequiredVersion>" + $newMinimumRequiredVersion + "</MinimumRequiredVersion>")
$projectFileText = $assemblyNameRegex.Replace($projectFileText, "<AssemblyName>" + $newAssemblyName + "</AssemblyName>")
$projectFileText = $productNameRegex.Replace($projectFileText, "<ProductName>" + $newProductName + "</ProductName>")
$projectFileText = $publishUrlRegex.Replace($projectFileText, "<PublishUrl>" + $newPublishUrl + "</PublishUrl>")

$webReferenceUrlRegex = New-Object System.Text.RegularExpressions.Regex "http:\/\/sr-mesap\/lot_tracker_backend\S*\/database.asmx", SingleLine
$projectFileText = $webReferenceUrlRegex.Replace($projectFileText, "http://sr-mesap/lot_tracker_backend" + $clickoncePathExt + "/database.asmx")
#csproj修改結束

#AssemblyInfo修改開始
$assemblyInfoFileText = [System.IO.File]::ReadAllText($assemblyInfoFilePath)

$assemblyTitleRegex = New-Object System.Text.RegularExpressions.Regex "AssemblyTitle\(\""(?<AssemblyTitle>\S*)\""\)", SingleLine
$assemblyVersionRegex = New-Object System.Text.RegularExpressions.Regex "AssemblyVersion\(\""(?<AssemblyVersion>\S+)\""\)", SingleLine
$assemblyFileVersionRegex = New-Object System.Text.RegularExpressions.Regex "AssemblyFileVersion\(\""(?<AssemblyFileVersion>\S+)\""\)", SingleLine

$assemblyInfoFileText = $assemblyTitleRegex.Replace($assemblyInfoFileText, "AssemblyTitle(""" + $assemblyTitle + """)")
$assemblyInfoFileText = $assemblyVersionRegex.Replace($assemblyInfoFileText, "AssemblyVersion(""" + $newMinimumRequiredVersion + """)")
$assemblyInfoFileText = $assemblyFileVersionRegex.Replace($assemblyInfoFileText, "AssemblyFileVersion(""" + $newMinimumRequiredVersion + """)")
#AssemblyInfo修改結束

#App.config修改開始
$appConfigFileText = [System.IO.File]::ReadAllText($appConfigFilePath)

$appConfigFileText = $webReferenceUrlRegex.Replace($appConfigFileText, "http://sr-mesap/lot_tracker_backend" + $clickoncePathExt + "/database.asmx")
#App.config修改結束

[System.IO.File]::WriteAllText($projectFilePath, $projectFileText)
Write "csproj [最小必要版本]已從 '$oldMinimumRequiredVersion' 升至 '$newMinimumRequiredVersion'"
Write "csproj [組件名稱]已改為 '$newAssemblyName'"
Write "csproj [產品名稱]已改為 '$newProductName'"
Write "csproj [發行資料夾位置]已改為 '$newPublishUrl'"

[System.IO.File]::WriteAllText($assemblyInfoFilePath, $assemblyInfoFileText)
Write "AssemblyInfo.cs [標題]已改為 '$assemblyTitle'"
Write "AssemblyInfo.cs [組件版本]已改為 '$newMinimumRequiredVersion'"
Write "AssemblyInfo.cs [檔案版本]已改為 '$newMinimumRequiredVersion'"

[System.IO.File]::WriteAllText($appConfigFilePath, $appConfigFileText)
Write "App.config [Web 參考 URL]已改為 'http://sr-mesap/lot_tracker_backend$clickoncePathExt/database.asmx'"