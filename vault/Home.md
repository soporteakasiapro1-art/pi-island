---
title: Pi Island
description: A native macOS dynamic island interface for the Pi coding agent
icon: i-lucide-terminal
order: 0
navigation:
  title: Home
  icon: i-lucide-home
  order: 0
---

![[Assets/Landing-1.png]]

Pi Island is a native macOS application that provides a dynamic island interface for interacting with the [Pi coding agent](https://github.com/badlogic/pi-mono). It lives in the notch area of your MacBook and provides:

- Real-time session monitoring with visual activity indicators
- Multi-session management with instant switching
- AI usage monitoring across multiple providers
- Markdown rendering with syntax-highlighted code blocks
- Dynamic updates when using Pi from the terminal

## Quick Start

1. Download the latest release from GitHub
2. Move `Pi Island.app` to `/Applications/`
3. Launch the app - it will appear in your notch area
4. Hover over the notch to expand, click to open

## Features

### Dynamic Island Interface

Pi Island uses the MacBook's notch area as its home. The interface:

- **Closed state**: Sits invisibly in the notch
- **Hint state**: Pulses when there's activity in a session
- **Open state**: Expands to show sessions list or chat view
- **Bounce animation**: Pi logo bounces when a response is ready

### Session Management

- View all Pi sessions across projects
- Resume any historical session instantly
- See real-time activity indicators:
  - Green dot: Active session with live RPC connection
  - Yellow dot: Recent external activity (terminal Pi)
  - Blue dot: Pi is thinking (waiting for response)

### Chat Interface

- Full markdown rendering with MarkdownUI
- Syntax highlighting for code blocks
- Collapsible thinking messages
- Model selector dropdown
- Real-time streaming responses

### AI Usage Monitor

Track your AI subscription usage across multiple providers:

- **Anthropic (Claude)**: 5-hour and weekly quotas with extra usage tracking
- **GitHub Copilot**: Monthly premium interactions quota
- **Google Gemini CLI**: Pro and Flash model quotas
- **Google Antigravity**: Per-model quotas for all available models
- **Synthetic**: Subscription, search, and tool call quotas

Features:
- Visual progress bars with linear pace markers
- Period bounds showing start/end times
- Time elapsed and remaining for each quota
- Pace comparison (ahead/behind linear usage)
- Automatic refresh with configurable intervals
- Notifications for warning and critical thresholds

## Requirements

- macOS 14.0 or later
- MacBook with notch (recommended) or any Mac
- Pi coding agent installed (`pi` command available)

## Next Steps

- [[1.guide/1.installation|Installation Guide]]
- [[1.guide/2.usage|Usage Guide]]
- [[1.guide/6.usage-monitor|AI Usage Monitor]]
- [[2.architecture/1.overview|Architecture Overview]]
- [[3.development/1.building|Building from Source]]
- [[Changelog]]
