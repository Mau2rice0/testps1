
function Start-CPULoad {
    param (
        [int]$load,
        [string]$computerName
    )
    $scriptBlock = {
        param ($load)
        $coreCount = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
        $jobs = @()
        for ($i = 0; $i -lt $coreCount; $i++) {
            $jobs += Start-Job -ScriptBlock {
                param($load)
                $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                while ($stopWatch.Elapsed.TotalSeconds -lt 60) {
                    $null = 1..1000000 | ForEach-Object { [math]::Sqrt($_) }
                }
            } -ArgumentList $load
        }
        $jobs | Wait-Job | Out-Null
        $jobs | Remove-Job
    }
    Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock -ArgumentList $load
}
