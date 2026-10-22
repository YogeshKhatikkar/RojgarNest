# fix_wakelock.ps1
# Yeh script wakelock ko wakelock_plus se replace karta hai aur cache saaf karta hai

Write-Host "🚀 Starting wakelock migration..." -ForegroundColor Cyan

# 1. pubspec.yaml mein dependency replace karein
$pubspec = "pubspec.yaml"
if (Test-Path $pubspec) {
    $content = Get-Content $pubspec -Raw
    # wakelock line ko comment karein aur wakelock_plus add karein
    $content = $content -replace '(?m)^\s*wakelock:\s*\^?[\d\.\+]+', '# wakelock: removed (replaced by wakelock_plus)'
    if ($content -notmatch 'wakelock_plus:') {
        # dependencies section ke andar add karein (simple approach)
        $content = $content -replace '(?m)^dependencies:\s*$', "dependencies:`n  wakelock_plus: ^1.2.8"
    }
    Set-Content $pubspec $content
    Write-Host "✅ pubspec.yaml updated" -ForegroundColor Green
} else {
    Write-Host "❌ pubspec.yaml not found!" -ForegroundColor Red
    exit 1
}

# 2. lib folder ke saare .dart files mein import aur class name replace karein
$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter *.dart
$replacedCount = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $original = $content

    # Import replace
    $content = $content -replace "package:wakelock/wakelock\.dart", "package:wakelock_plus/wakelock_plus.dart"
    
    # Class name replace (Wakelock. -> WakelockPlus.)
    $content = $content -replace '\bWakelock\.', 'WakelockPlus.'

    if ($content -ne $original) {
        Set-Content $file.FullName $content
        Write-Host "  Updated: $($file.Name)" -ForegroundColor Yellow
        $replacedCount++
    }
}

Write-Host "✅ Replaced in $replacedCount Dart files" -ForegroundColor Green

# 3. Flutter cache saaf karein aur dependencies fetch karein
Write-Host "🧹 Cleaning Flutter cache..." -ForegroundColor Cyan
flutter clean
Write-Host "📦 Getting dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "🎉 Done! Ab aap build command chala sakte hain:" -ForegroundColor Green
Write-Host "   flutter build apk --release --split-per-abi --tree-shake-icons" -ForegroundColor White