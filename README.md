<div align="center">
<a href="https://github.com/HotCakeX/WinSecureDNSMgr"><img src="https://raw.githubusercontent.com/HotCakeX/WinSecureDNSMgr/main/GitHubIcon.png" alt="Avatar" width="300" name="readme-top"></a>

# WinSecureDNSMgr module

Quick, proper and automatic way to configure Secure DNS in Windows with multiple available operation modes

<a href="https://www.powershellgallery.com/packages/WinSecureDNSMgr/"><strong>PowerShell Gallery</strong></a>

<a href="https://github.com/HotCakeX/WinSecureDNSMgr/discussions">Discussion</a>
·
<a href="https://github.com/HotCakeX/WinSecureDNSMgr/issues">Report Issue</a>

![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/WinSecureDNSMgr?style=plastic&logo=powershell&labelColor=rgb(255%2C29%2C206)&color=rgb(201%2C255%2C229))

![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/WinSecureDNSMgr?style=plastic&labelColor=rgb(255%2C29%2C206)&color=rgb(201%2C255%2C229))

</div>

<details>
  <summary>Table of Contents</summary>

1. <a href="#about-the-module">About The Module</a>
2. <a href="#features">Features</a>
3. <a href="#recommended-setup">Recommended setup</a>
4. <a href="#prerequisites">Prerequisites</a>
5. <a href="#installation">Installation</a>
6. <a href="#usage">Usage</a>
   - <a href="#built-in-doh-examples">Built-in DoH examples</a>
   - <a href="#custom-doh-examples">Custom DoH examples</a>
   - <a href="#dynamic-doh-examples">Dynamic DoH examples</a>
7. <a href="#operation-modes">Operation modes</a>

</details>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## About The Module

This is a PowerShell module that can simplify setting up DNS over HTTPS in Windows for various scenarios mentioned in the Operation modes section.

It can automatically identify the correct and active network adapter/interface and set Secure DNS settings for it based on parameters supplied by user.
That means it will detect the correct network adapter/interface even if you are using:

- Windows built-in VPN connections (PPTP, L2TP, SSTP, IKEv2)
- OpenVPN
- TUN/TAP virtual adapters (a lot of programs use them, including WireGuard)
- Hyper-V virtual switches (Internal, Private, External, all at the same time)
- Cloudflare WARP client

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Features

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="30">  Strongest possible End-to-End encrypted workflow

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="30"> Created, targeted and tested on the latest version of Windows, on physical hardware and Virtual Machines

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="30"> To make sure the module will always be able to acquire the IP address(s) of the DoH server, specially in case of dynamic DoH server when the currently set system IPv4s and IPv6s might be outdated, the module performs DNS queries in this exact order:

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="20"> First tries using [Cloudflare's main encrypted API](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/make-api-requests/) to get the IP address(s) of the DoH server's domain.

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="20"> If 1st one fails, tries using the Cloudflare's secondary encrypted API to get the IP address(s) of the DoH server's domain.

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="20"> If 2nd one fails, tries using [Google's main encrypted API](https://developers.google.com/speed/public-dns/docs/doh/) to get the IP address(s) of the DoH server's domain.

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="20"> If 3rd one fails, tries using Google's secondary encrypted API to get the IP address(s) of the DoH server's domain.

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="20"> if 4th one fails, tries using any system DNS that is available to get the IP address(s) of the DoH server's domain.

<img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/911587042608156732.webp" width="30"> All of the connections to Cloudflare and Google servers use direct IP, are set to use [TLS 1.3](https://curl.se/docs/manpage.html#--tls13-ciphers) with `HTTP/3`, with the exception of the last try which uses system DNS as the last resort before giving up.

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Recommended setup

* Use Cloudflare DNS over HTTPS which is a built-in DoH provider in Windows, it's the safest, fastest and most reliable.

* If you can't use publicly known DNS over HTTPS providers for any reason, you can create your own DoH server and domain for free using a [serverless Secure DNS](https://github.com/serverless-dns/serverless-dns) and [freenom](https://www.freenom.com/). They are more stealthy, hard or costly for ISPs, governments etc. to detect or block.

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Prerequisites

* The latest stable version of PowerShell
  * [Install it from GitHub](https://github.com/PowerShell/PowerShell/releases/latest)
  * Using Winget `Winget install Microsoft.PowerShell`
  * Store installed version of PowerShell is not supported for the Dynamic DoH (DDOH) operation mode.

* Latest version of Windows

If planning to use the module in dynamic DoH mode and it's the first time installing PowerShell on your machine, restart your computer after installation so task scheduler will recognize `pwsh.exe` required for running this module.

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Installation

### Install from [PowerShell Gallery](https://www.powershellgallery.com/packages/WinSecureDNSMgr/)

```powershell
Install-Module -Name WinSecureDNSMgr -force
```

<br>

if you already have the module installed, make sure [it's up-to-date](https://learn.microsoft.com/en-us/powershell/module/powershellget/update-module)

```powershell
Update-Module -Name WinSecureDNSMgr -force
```

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Usage

<br>

![Animated APNG demonstrating how the Harden Windows Security PowerShell script works](https://github.com/HotCakeX/WinSecureDNSMgr/raw/main/Module%20Operation%20Demo.apng)

<br>

### Built-in DoH examples

```powershell
Set-BuiltInWinSecureDNS -DoHProvider Cloudflare
```

```powershell
Set-DOH -DoHProvider Cloudflare
```

<br>

### Custom DoH examples

```powershell
Set-CustomWinSecureDNS -DoHTemplate https://example.com/
```

```powershell
Set-CDOH -DoHTemplate https://example.com/
```

```powershell
Set-CDOH -DoHTemplate https://example.com -IPV4s 1.2.3.4 -IPV6s 2001:db8::8a2e:370:7334
```

<br>

### Dynamic DoH examples

```powershell
Set-DynamicIPDoHServer -DoHTemplate https://example.com/
```

```powershell
Set-DDOH -DoHTemplate https://example.com/
```

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

## Operation modes

### <img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/PinkDash.webp" width="30">  DNS over HTTPS in Windows using the default built-in OS DoH providers

* This is the default mode of operation for this module. It will set up DNS over HTTPS in Windows using the default built-in OS DoH providers, which are Cloudflare, Quad9 and Google.

* In this mode of operation, the active network adapter/interface will be detected automatically but you will have the option to review it and choose a different one if you like.

### <img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/PinkDash.webp" width="30">  DNS over HTTPS in Windows using a custom DoH provider that has **static** IP address(s)

* This mode of operation is useful when you want to use a custom DoH provider that has static IP address(s). You can supply the module with a DoH template and then you have 2 options

  * Let the module automatically detect the IP address(s) of the DoH server and set them in Windows
  * Supply the module with the IP address(s) of the DoH server and let it set them in Windows

* In this mode of operation, the active network adapter/interface will be detected automatically but you will have the option to review it and choose a different one if you like.

### <img src="https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/images/WebP/PinkDash.webp" width="30">  DNS over HTTPS in Windows using a custom DoH provider that has **dynamic** IP address(s)

* This mode of operation is useful when you want to use a custom DoH provider that has dynamic IP address(s).

* Once you run the module in this mode for the first time and supply it with your DoH template, it will create a scheduled task that will run the module automatically based on 2 distinct criteria:

  - As soon as Windows detects the current DNS servers are unreachable
  - Every 6 hours in order to check for new IP changes for the dynamic DoH server

    - You can fine-tune the interval in Task Scheduler GUI if you like. I haven't had any downtimes in my tests because the module runs milliseconds after Windows detects DNS servers are unreachable, and even then, Windows still maintains the current active connections using the DNS cache. if your experience is different, please let me know [on GitHub](https://github.com/HotCakeX/WinSecureDNSMgr/issues).

* The module and the scheduled task will use both IPv4s and IPv6s of the dynamic DoH server. The task will run whether or not any user is logged on.

* In this mode of operation, the active network adapter/interface will be detected automatically.

<br>

<p align="right"><a href="#readme-top">💡(back to top)</a></p>

<br>

<img src="https://github.com/HotCakeX/Harden-Windows-Security/raw/main/images/Gifs/1pxRainbowLine.gif" width= "300000" alt="horizontal super thin rainbow RGB line">

<br>

## Upcoming features

* DNS over TLS (DoT) support
  * It's currently [only available in Windows insider builds](https://techcommunity.microsoft.com/t5/networking-blog/dns-over-tls-available-to-windows-insiders/bc-p/3714816), Dev and Canary channels.
