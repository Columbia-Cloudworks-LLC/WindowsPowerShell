param(
    [string]$Nickname
)

# Load the SpeechSynthesizer class from the System.Speech assembly
Add-Type -AssemblyName System.Speech

# Create an instance of the SpeechSynthesizer class
$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer

# Get current date and time information
$currentDate = Get-Date
$dayOfWeek = $currentDate.DayOfWeek
$month = $currentDate.ToString("MMMM")
$day = $currentDate.Day
$hour = $currentDate.Hour

if($Nickname) {
    $readAloudName = $Nickname
} else {
    $readAloudName = $env:UserName
}

# Determine if it is morning, afternoon, or evening
$greeting = switch ($hour) {
    { $_ -ge 0 -and $_ -lt 12 } { "Good morning, $($readAloudName)!" }
    { $_ -ge 12 -and $_ -lt 17 } { "Good afternoon, $($readAloudName)!" }
    default { "Good evening, $($readAloudName)!" }
}

# Determine the closest quarter-hour
# NOTE: These values are customized to my personal taste and how I think about time.
#       Feel free to adjust the values to suit your own preferences.
$minute = $currentDate.Minute
$quarterHour = switch ($minute) {
    { $_ -eq 0 } { "exactly" }
    { $_ -ge 1 -and $_ -lt 15 } { "just after" }
    { $_ -ge 15 -and $_ -lt 25 } { "a quarter past" }
    { $_ -ge 25 -and $_ -lt 45 } { "half past" }
    { $_ -ge 45 -and $_ -lt 50 } { "a quarter to" }
    { $_ -ge 50 -and $_ -lt 60 } { "almost" }
    default { "approximately" }
}

# Adjust hour if it's close to the next hour for "a quarter to" or at the tail end for "o'clock"
if ($quarterHour -eq "a quarter to" -or ($quarterHour -eq "almost")) {
    $hour++
    if ($hour -eq 24) { $hour = 0 } # Wrap around if hour exceeds 23 (i.e., midnight)
}

# Format the hour into 12-hour format and determine AM/PM
$amPm = if ($hour -ge 12) { "PM" } else { "AM" }
$formattedHour = if ($hour -gt 12) { $hour - 12 } elseif ($hour -eq 0) { 12 } else { $hour }

# Get the local time zone and determine if it's daylight saving time
$timezone = [System.TimeZoneInfo]::Local
$isDaylight = $timezone.IsDaylightSavingTime($currentDate)
if ($timezone.SupportsDaylightSavingTime) {
    if ($isDaylight) {
        $timeZoneName = $timezone.DaylightName
    } else {
        $timeZoneName = $timezone.StandardName
    }
} else {
    $timeZoneName = $timezone.StandardName
}

# Get the system uptime in hours and minutes
$uptime = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
# Convert the uptime for use in New-TimeSpan
$uptime = [Management.ManagementDateTimeConverter]::ToDateTime($uptime)
$uptimeSpan = New-TimeSpan -Start $uptime -End $currentDate
$uptimeHours = $uptimeSpan.Hours
$uptimeMinutes = $uptimeSpan.Minutes
if($uptimeHours -eq 1) {
    $uptimeHours = "1 hour"
} else {
    $uptimeHours = "$uptimeHours hours"
}
if($uptimeMinutes -eq 1) {
    $uptimeMinutes = "1 minute"
} else {
    $uptimeMinutes = "$uptimeMinutes minutes"
}
$uptimePhrase = "Your computer has been running for $uptimeHours and $uptimeMinutes."

# Construct the phrase
if ($quarterHour -eq "approximately" -and $minute -lt 60) {
    $phrase = "$greeting Today is $dayOfWeek, $month $day. The time is $formattedHour $amPm $timeZoneName. $uptimePhrase"
} else {
    $phrase = "$greeting Today is $dayOfWeek, $month $day. The time is $quarterHour $formattedHour $amPm $timeZoneName. $uptimePhrase"
}

# Use the Speak method to say the phrase
$synthesizer.Speak($phrase)
