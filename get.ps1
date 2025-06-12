$ComputerName = "srv03-maurice.maurice.local"

$ScriptBlock = {
    Get-Process | ForEach-Object {
        $proc = $_
        Get-Service | Where-Object { $_.Name -eq $proc.Name } | ForEach-Object {
            [PSCustomObject]@{
                ServiceName = $_.DisplayName
                Status      = $_.Status
                CPU         = $proc.CPU
                ProcessId   = $proc.Id
            }
        }
    } | Sort-Object -Property CPU -Descending | Select-Object -First 5 ServiceName, Status, CPU, ProcessId
}

Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock


