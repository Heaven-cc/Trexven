$ErrorActionPreference='Stop'
$taskRoot='C:\Users\USER\AndroidStudioProjects\Trexven'
$target=Join-Path $taskRoot '.batch3-tools\replay4\supabase'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$config=Get-Content -LiteralPath (Join-Path $taskRoot '.batch3-tools\disposable\supabase\config.toml') -Raw
$config=$config.Replace('54321','54351').Replace('54322','54352').Replace('54320','54350').Replace('54323','54353').Replace('54324','54354')
$config | Set-Content -LiteralPath (Join-Path $target 'config.toml') -Encoding utf8
$ErrorActionPreference='Continue'
wsl.exe -d Ubuntu -- env SUPABASE_HOME=/var/tmp/trexven-batch3-native SUPABASE_NATIVE_POSTGRES_USER=trexven-b2-pg /mnt/c/Users/USER/AndroidStudioProjects/Trexven/.batch2-tools/bin/supabase_linux_v2.120.0/supabase --workdir /mnt/c/Users/USER/AndroidStudioProjects/Trexven/.batch3-tools/replay4 start --stack trexven-batch3-replay4 --runtime native --exclude functions,studio,mail,analytics,pooler --eager --output-format json *> (Join-Path $taskRoot '.batch3-tools\start4.log')
Write-Output "REPLAY4_START_EXIT=$LASTEXITCODE"
