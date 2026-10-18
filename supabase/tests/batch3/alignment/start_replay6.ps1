$ErrorActionPreference='Stop'
$taskRoot='C:\Users\USER\AndroidStudioProjects\Trexven'
$target=Join-Path $taskRoot '.batch3-tools\replay6\supabase'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$config=Get-Content -LiteralPath (Join-Path $taskRoot '.batch3-tools\disposable\supabase\config.toml') -Raw
$config=$config.Replace('54321','54371').Replace('54322','54372').Replace('54320','54370').Replace('54323','54373').Replace('54324','54374')
$config | Set-Content -LiteralPath (Join-Path $target 'config.toml') -Encoding utf8
$ErrorActionPreference='Continue'
wsl.exe -d Ubuntu -- env SUPABASE_HOME=/var/tmp/trexven-batch3-native SUPABASE_NATIVE_POSTGRES_USER=trexven-b2-pg /mnt/c/Users/USER/AndroidStudioProjects/Trexven/.batch2-tools/bin/supabase_linux_v2.120.0/supabase --workdir /mnt/c/Users/USER/AndroidStudioProjects/Trexven/.batch3-tools/replay6 start --stack trexven-batch3-replay6 --runtime native --exclude functions,studio,mail,analytics,pooler --eager --output-format json *> (Join-Path $taskRoot '.batch3-tools\start6.log')
Write-Output "REPLAY6_START_EXIT=$LASTEXITCODE"

