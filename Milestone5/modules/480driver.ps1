Import-Module '480-utils' -Force
480Banner
$conf=Get-480Config -config_path "./480.json"
480Connect -server $conf.venter_server
Menu($conf)