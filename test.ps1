#Skript zum auslasten der cpu und des rams über remote powershell
param(
    [int]$cpuLoad = 100,
    [int]$ramLoad = 3145728000, # 3000MB in bytes
    [string]$computerName = "srv03-maurice.maurice.local"
)

# Funktion zum Erzeugen von CPU-Last
function Start-CPULoad {
    param (
        [int]$load,
        [string]$computerName
    )
    $scriptBlock = {
        param ($load)
        $coreCount = [Environment]::ProcessorCount
        $jobs = @()
        for ($i = 0; $i -lt $coreCount; $i++) {
            $jobs += Start-Job -ScriptBlock {
                param($load)
                $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                while ($stopWatch.Elapsed.TotalSeconds -lt 60) {
                    $null = 1..$load | ForEach-Object { $_ * $_ }
                }
            } -ArgumentList $load
        }
        $jobs | ForEach-Object { Wait-Job $_; Remove-Job $_ }
    }
    Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock -ArgumentList $load
}
# Funktion zum Erzeugen von RAM-Last
function Start-RAMLoad {
    param (
        [int]$load,
        [string]$computerName
    )
    $scriptBlock = {
        param ($load)
        $array = New-Object byte[] $load
        [System.GC]::Collect()
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock -ArgumentList $load
}
# Starten der CPU- und RAM-Last
Start-CPULoad -load $cpuLoad -computerName $computerName
Start-RAMLoad -load $ramLoad -computerName $computerName
# Ausgabe der gestarteten Last
Write-Host "CPU Load: $cpuLoad% auf $computerName gestartet."

#Abfrage des RAM-Verbrauchs
$ramUsage = Invoke-Command -ComputerName $computerName -ScriptBlock {
    Get-WmiObject Win32_OperatingSystem | Select-Object FreePhysicalMemory, TotalVisibleMemorySize
}
$freeMemory = [math]::Round($ramUsage.FreePhysicalMemory / 1024, 2)
$totalMemory = [math]::Round($ramUsage.TotalVisibleMemorySize / 1024, 2)
Write-Host "RAM Usage on $computerName: $([math]::Round($totalMemory - $freeMemory, 2)) MB used out of $totalMemory MB total."
# Abfrage der CPU-Auslastung
$cpuUsage = Invoke-Command -ComputerName $computerName -ScriptBlock {
    Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
}
Write-Host "CPU Usage on $computerName: $cpuUsage%."
# Warten auf Benutzereingabe zum Beenden
Read-Host "Press Enter to stop the load and exit the script."
