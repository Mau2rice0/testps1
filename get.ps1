$ComputerName = "srv03-maurice.maurice.local"

$ScriptBlock = {
    Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First 5 Name, CPU, Id
}

Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock

