$port = 9999  
$listener = [System.Net.Sockets.TcpListener]::new('127.0.0.1', $port)  
$listener.Start()  
Write-Host "Listening on port $port..."  
  
while ($true) {  
    $client = $listener.AcceptTcpClient()  
    $stream = $client.GetStream()  
    $reader = [System.IO.StreamReader]::new($stream)  
    $message = $reader.ReadLine()  
    Write-Host "Triggered: $message"  
  
    # Always run wlines-run, ignore message content  
    wlines-run  
  
    $client.Close()  
}
