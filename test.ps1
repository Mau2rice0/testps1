<#
.SYNOPSIS
    Erzeugt CPU- und RAM-Last auf einem Remote-Computer via PowerShell-Remoting.

.DESCRIPTION
    Mit diesem Skript wird eine Remote-PSSession zum Zielrechner hergestellt. In dieser
    Session werden zwei Hintergrundjobs gestartet:
      - Ein CPU-Job, der in einer Schleife rechenintensive Operationen ausführt.
      - Ein RAM-Job, der ein großes Byte-Array anlegt, um Speicher zu belegen.
    Nachdem die Jobs gestartet wurden, wird der aktuelle CPU- und RAM-Verbrauch abgefragt.
    Über eine Benutzereingabe (Enter) können die Jobs gestoppt und die Remote-Session beendet werden.

.PARAMETER CpuLoad
    Gibt die Intensität der CPU-Berechnungen an. Höhere Werte bewirken mehr Last.

.PARAMETER RamLoadBytes
    Gibt die Anzahl Bytes an, die im Arbeitsspeicher belegt werden sollen.
    
.PARAMETER ComputerName
    Der Netzwerkname oder die IP-Adresse des Zielcomputers.

.EXAMPLE
    .\StressTest.ps1 -CpuLoad 100 -RamLoadBytes 3145728000 -ComputerName "RemoteServer.domain.local"
#>
param(
    [Parameter(Mandatory = $false)]
    [int]$CpuLoad = 100,
    
    [Parameter(Mandatory = $false)]
    [int]$RamLoadBytes = 3145728000,  # 3000 MB in Bytes
    
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = "srv03-maurice.maurice.local"
)

# Aufbau einer Remote-PSSession
try {
    $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "Remote-Session zu $ComputerName erfolgreich erstellt."
}
catch {
    Write-Error "Fehler beim Erstellen der Remote-Session zu $ComputerName: $_"
    exit 1
}

# Funktion: CPU-Last erzeugen (rechnet 60 Sekunden lang intensiv)
function Start-CPULoad {
    param (
        [int]$Load,
        [PSSession]$Session
    )
    $scriptBlock = {
        param ($Load)
        $stopWatch = [Diagnostics.Stopwatch]::StartNew()
        while ($stopWatch.Elapsed.TotalSeconds -lt 60) {
            # Intesive Berechnung: Wiederholen der Multiplikation
            for ($i = 0; $i -lt $Load; $i++) {
                $null = $i * $i
            }
        }
        "CPU-Last beendet"
    }
    # Ausführung als Job in der bestehenden Remote-Session
    Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $Load -AsJob
}

# Funktion: RAM-Last erzeugen (allokiert den gewünschten Speicher)
function Start-RAMLoad {
    param (
        [int]$Load,
        [PSSession]$Session
    )
    $scriptBlock = {
        param ($Load)
        try {
            # Byte-Array allokieren, um den RAM zu belegen
            $buffer = New-Object Byte[] $Load
            # Optional: Array mit Werten befüllen, um die tatsächliche Nutzung zu forcieren
            for ($i = 0; $i -lt $buffer.Length; $i++) {
                $buffer[$i] = 0xFF
            }
            Write-Output "RAM von $Load Bytes belegt."
            # Endlosschleife, um den belegten Speicher zu halten
            while ($true) { Start-Sleep -Seconds 1 }
        }
        catch {
            Write-Error "Fehler beim Allozieren des RAM: $_"
        }
    }
    # Ausführung als Job in der bestehenden Remote-Session
    Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $Load -AsJob
}

# Starten der Jobs auf dem Remote-Rechner
$cpuJob = Start-CPULoad -Load $CpuLoad -Session $session
$ramJob = Start-RAMLoad -Load $RamLoadBytes -Session $session

Write-Host "CPU-Last ($CpuLoad) und RAM-Last ($RamLoadBytes Bytes) wurden auf $ComputerName gestartet."
Write-Host "Warte 5 Sekunden, um mit der aktuellen Auslastung zu beginnen..."
Start-Sleep -Seconds 5

# Abfrage der aktuellen RAM-Auslastung mittels Get-CimInstance (Modernere Alternative zu Get-WmiObject)
try {
    $osInfo = Invoke-Command -Session $session -ScriptBlock {
        Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object FreePhysicalMemory, TotalVisibleMemorySize
    }
    $freeMemoryMB  = [math]::Round($osInfo.FreePhysicalMemory / 1024, 2)
    $totalMemoryMB = [math]::Round($osInfo.TotalVisibleMemorySize / 1024, 2)
    $usedMemoryMB  = [math]::Round($totalMemoryMB - $freeMemoryMB, 2)
    Write-Host "RAM-Auslastung auf $ComputerName: $usedMemoryMB MB verwendet von $totalMemoryMB MB (frei: $freeMemoryMB MB)."
}
catch {
    Write-Warning "Konnte die RAM-Auslastung nicht abfragen: $_"
}

# Abfrage der CPU-Auslastung
try {
    $cpuInfo = Invoke-Command -Session $session -ScriptBlock {
        Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average |
        Select-Object -ExpandProperty Average
    }
    Write-Host "CPU-Auslastung auf $ComputerName: $cpuInfo%."
}
catch {
    Write-Warning "Konnte die CPU-Auslastung nicht abfragen: $_"
}

# Benutzerdrücken zum Beenden der Last
Read-Host "Drücke Enter, um die Belastung zu stoppen und das Skript zu beenden."

# Stoppen und Entfernen der Jobs und Schließen der Remote-Session
if ($cpuJob.State -eq 'Running') {
    Stop-Job -Job $cpuJob -ErrorAction SilentlyContinue
    Write-Host "CPU-Job gestoppt."
}
if ($ramJob.State -eq 'Running') {
    Stop-Job -Job $ramJob -ErrorAction SilentlyContinue
    Write-Host "RAM-Job gestoppt."
}

Remove-PSSession -Session $session
Write-Host "Remote-Session zu $ComputerName wurde beendet."
