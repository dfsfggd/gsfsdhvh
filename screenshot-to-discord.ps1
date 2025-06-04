# Screenshot to Discord PowerShell Script
# This script captures a screenshot and sends it to a Discord channel via webhook
#
# USAGE:
# Interactive mode: .\screenshot-to-discord.ps1 -Interactive
# Command line:     .\screenshot-to-discord.ps1 -WebhookUrl "YOUR_WEBHOOK_URL" -Message "Your message"
# Auto-interactive: .\screenshot-to-discord.ps1  (runs interactive if no webhook provided)
#
# Your webhook URL is pre-configured in the script for convenience.

param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "",

    [Parameter(Mandatory=$false)]
    [string]$Message = "Screenshot captured",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "$env:TEMP\screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png",

    [Parameter(Mandatory=$false)]
    [switch]$Interactive
)

# Function to capture screenshot
function Capture-Screenshot {
    param([string]$FilePath)

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Get screen dimensions
        $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $Width = $Screen.Width
        $Height = $Screen.Height
        $Left = $Screen.Left
        $Top = $Screen.Top

        # Create bitmap
        $Bitmap = New-Object System.Drawing.Bitmap $Width, $Height
        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

        # Capture screen
        $Graphics.CopyFromScreen($Left, $Top, 0, 0, $Bitmap.Size)

        # Save screenshot
        $Bitmap.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)

        # Cleanup
        $Graphics.Dispose()
        $Bitmap.Dispose()

        Write-Host "Screenshot saved to: $FilePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to capture screenshot: $($_.Exception.Message)"
        return $false
    }
}

# Function to send file to Discord
function Send-ToDiscord {
    param(
        [string]$WebhookUrl,
        [string]$FilePath,
        [string]$Message
    )

    try {
        # Check if file exists
        if (-not (Test-Path $FilePath)) {
            throw "Screenshot file not found: $FilePath"
        }

        # Prepare multipart form data
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        # Read file content
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath)

        # Build form data
        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"content`"",
            "",
            $Message,
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
            "Content-Type: image/png",
            "",
            [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBytes),
            "--$boundary--"
        ) -join $LF

        # Convert to bytes
        $body = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes($bodyLines)

        # Send request
        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary"

        Write-Host "Screenshot sent to Discord successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to send to Discord: $($_.Exception.Message)"
        return $false
    }
}

# Interactive menu function
function Show-InteractiveMenu {
    # Default webhook URL (replace with your own)
    $DEFAULT_WEBHOOK = "https://discord.com/api/webhooks/1377908353509888052/IgQqiPb5N2pPjIzWUbXCEubea3iiI682KSj9kc9ZMmbr6QVLoNbhAbNQufJF6yfQHUG5"

    Write-Host "Screenshot to Discord - Interactive Mode" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    # Get webhook URL
    if ([string]::IsNullOrEmpty($WebhookUrl)) {
        Write-Host "Enter Discord webhook URL (or press Enter to use default):" -ForegroundColor Yellow
        $inputWebhook = Read-Host
        if ([string]::IsNullOrEmpty($inputWebhook)) {
            $WebhookUrl = $DEFAULT_WEBHOOK
            Write-Host "Using default webhook URL" -ForegroundColor Green
        } else {
            $WebhookUrl = $inputWebhook
        }
    }

    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor White
    Write-Host "1. Take basic screenshot" -ForegroundColor Green
    Write-Host "2. Take screenshot with custom message" -ForegroundColor Green
    Write-Host "3. Take screenshot with timestamp" -ForegroundColor Green
    Write-Host "4. Test webhook (text only)" -ForegroundColor Green
    Write-Host "5. Exit" -ForegroundColor Red

    $choice = Read-Host "Enter your choice (1-5)"

    switch ($choice) {
        "1" {
            Write-Host "Taking basic screenshot..." -ForegroundColor Yellow
            return @{
                WebhookUrl = $WebhookUrl
                Message = "Screenshot captured"
                Action = "screenshot"
            }
        }

        "2" {
            $customMessage = Read-Host "Enter custom message"
            Write-Host "Taking screenshot with custom message..." -ForegroundColor Yellow
            return @{
                WebhookUrl = $WebhookUrl
                Message = $customMessage
                Action = "screenshot"
            }
        }

        "3" {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "Taking screenshot with timestamp..." -ForegroundColor Yellow
            return @{
                WebhookUrl = $WebhookUrl
                Message = "Screenshot captured at $timestamp"
                Action = "screenshot"
            }
        }

        "4" {
            Write-Host "Testing webhook..." -ForegroundColor Yellow
            return @{
                WebhookUrl = $WebhookUrl
                Message = "Test message from PowerShell script - $(Get-Date)"
                Action = "test"
            }
        }

        "5" {
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0
        }

        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            return Show-InteractiveMenu
        }
    }
}

# Function to test webhook with text message
function Test-Webhook {
    param([string]$WebhookUrl, [string]$Message)

    try {
        $testMessage = @{
            content = $Message
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $testMessage -ContentType "application/json" | Out-Null
        Write-Host "[SUCCESS] Webhook test successful!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Webhook test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
function Start-ScreenshotCapture {
    param([string]$WebhookUrl, [string]$Message, [string]$OutputPath)

    Write-Host "Starting screenshot capture and Discord upload..." -ForegroundColor Cyan

    # Validate webhook URL
    if ($WebhookUrl -notmatch "^https://discord(app)?\.com/api/webhooks/") {
        Write-Error "Invalid Discord webhook URL format"
        return $false
    }

    # Capture screenshot
    Write-Host "Capturing screenshot..." -ForegroundColor Yellow
    $screenshotSuccess = Capture-Screenshot -FilePath $OutputPath

    if ($screenshotSuccess) {
        # Send to Discord
        Write-Host "Sending to Discord..." -ForegroundColor Yellow
        $uploadSuccess = Send-ToDiscord -WebhookUrl $WebhookUrl -FilePath $OutputPath -Message $Message

        # Cleanup temporary file
        try {
            Remove-Item $OutputPath -Force
            Write-Host "Temporary file cleaned up" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Could not delete temporary file: $OutputPath"
        }

        if ($uploadSuccess) {
            Write-Host "Process completed successfully!" -ForegroundColor Green
            return $true
        } else {
            Write-Error "Failed to upload to Discord"
            return $false
        }
    } else {
        Write-Error "Failed to capture screenshot"
        return $false
    }
}

# Main execution
if ($Interactive -or [string]::IsNullOrEmpty($WebhookUrl)) {
    # Interactive mode
    $menuResult = Show-InteractiveMenu

    if ($menuResult.Action -eq "test") {
        Test-Webhook -WebhookUrl $menuResult.WebhookUrl -Message $menuResult.Message
    } elseif ($menuResult.Action -eq "screenshot") {
        $success = Start-ScreenshotCapture -WebhookUrl $menuResult.WebhookUrl -Message $menuResult.Message -OutputPath $OutputPath
        if (-not $success) { exit 1 }
    }
} else {
    # Command line mode
    $success = Start-ScreenshotCapture -WebhookUrl $WebhookUrl -Message $Message -OutputPath $OutputPath
    if (-not $success) { exit 1 }
}
