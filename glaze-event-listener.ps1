using namespace System.Net.WebSockets  
using namespace System.Text  
  
$ws = [ClientWebSocket]::new()  
$ct = [System.Threading.CancellationToken]::None  
$ws.ConnectAsync('ws://127.0.0.1:6123', $ct).Wait() | Out-Null  
  
$subMsg = [Encoding]::UTF8.GetBytes('sub -e binding_modes_changed')  
$ws.SendAsync([ArraySegment[byte]]$subMsg, [WebSocketMessageType]::Text, $true, $ct).Wait() | Out-Null  
 
Write-Host "Listening for BindingModesChanged events..."  
 
$prevActiveModes = @()
$buffer = New-Object byte[] 4096  
try {  
    while ($true) {  
        $recv = $ws.ReceiveAsync([ArraySegment[byte]]$buffer, $ct).Result  
        $json = [Encoding]::UTF8.GetString($buffer, 0, $recv.Count)  
  
        $isActive = @($json | jq -r '.data.newBindingModes[]?.name // empty')  
        $wasActive = 'wlines' -in $prevActiveModes
        Write-Host $isActive
        Write-Host $msg
        if (-not $wasActive -and $isActive){
            try {  
                # Toggle wlines.exe: kill if running, start if not  
                if (Get-Process -Name "wlines" -ErrorAction SilentlyContinue) {  
                    taskkill /IM wlines.exe /F  
                    glazewm command wm-disable-binding-mode --name "wlines"
                } else {  
                    $daemonClient = [System.Net.Sockets.TcpClient]::new('127.0.0.1', 9999)  
                    $daemonStream = $daemonClient.GetStream()  
                    $daemonWriter = [System.IO.StreamWriter]::new($daemonStream)  

                    $daemonWriter.WriteLine($msg)  
                    $daemonWriter.Flush()  
                    $daemonClient.Close()  
                    glazewm command wm-disable-binding-mode --name "wlines"
                }
            } catch {  
                Write-Warning "Failed to send '$msg': $_"  
            } 
        }
        elseif ( $wasActive -and -not $isActive ) {
            Write-Host "safely exited binding mode"
        }
    }  
} finally {  
    $ws.CloseAsync([WebSocketCloseStatus]::NormalClosure, $null, $ct).Wait() | Out-Null  
}
