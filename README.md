# FrameOS

**A modern operating system. A better way to work.**

---

## Overview

FrameOS is a modern, productivity-focused Linux distribution designed to deliver a premium desktop experience for professionals, businesses, students, developers and everyday users.

Built on Ubuntu and powered by GNOME, FrameOS combines the flexibility of Linux with an elegant desktop interface, intelligent workflow management, cross-device connectivity and an integrated ecosystem of productivity tools.

FrameOS is not simply a customized desktop theme. It is designed as a complete operating system with its own visual identity, system integrations, native components, productivity features and installation experience.

Our goal is to make Linux more intuitive, productive, consistent and accessible without sacrificing performance, privacy or user control.

## Design Philosophy

FrameOS is built around six fundamental principles:

- **Productivity** — reduce unnecessary interactions and simplify everyday workflows.
- **Design** — deliver a consistent, modern and refined desktop experience.
- **Performance** — prioritize responsiveness, efficiency and resource management.
- **Connectivity** — create meaningful integration between computers and mobile devices.
- **Privacy** — keep users in control of their devices and personal data.
- **Compatibility** — preserve access to the established Linux application ecosystem.

## FrameUI

FrameUI is the custom desktop experience designed specifically for FrameOS.

It combines the capabilities of GNOME Shell with a sophisticated visual language inspired by modern glass-based interfaces and professional desktop environments.

### Interface Features

- Floating three-section top bar.
- Dynamic application global menu.
- Compact, customizable application dock.
- Modular Control Center.
- Frosted glass surfaces and background blur.
- Refined window decorations.
- macOS-inspired window controls.
- Rounded application sidebars.
- Smooth desktop animations.
- Consistent spacing and typography.
- Fluent iconography.
- Bibata Modern Ice cursor theme.
- Three-dimensional workspace transitions.
- Light, Dark, Solid and High Contrast appearance modes.
- Multi-monitor and HiDPI support.

FrameUI is designed to remain visually consistent while providing a practical environment for extended periods of professional work.

## Native FrameOS Technologies

FrameOS introduces a collection of integrated technologies designed to extend the capabilities of a traditional Linux desktop.

### Connectivity

| Technology | Description |
|---|---|
| Frame Connect | Integration between computers and Android or iOS devices. |
| Frame Drop | Fast local file transfers between compatible devices. |
| Frame Secure Share | Temporary, controlled and secure file sharing. |
| Frame Desktop Handoff | Cross-device workflow continuation where supported. |

### Productivity

| Technology | Description |
|---|---|
| Frame Projects | Organize applications, documents, folders and links into dedicated work environments. |
| Frame Timeline | Restore previous work contexts through a privacy-conscious activity history. |
| Frame Document Hub | Centralized access to documents, templates and office applications. |
| Frame Quick Preview | Preview documents and multimedia without launching full applications. |
| Frame App Groups | Launch multiple related applications with a single action. |
| Frame Session | Save and restore supported desktop working environments. |
| Frame Command Center | Execute system actions, workflows and productivity commands from a unified interface. |
| Frame Work Report | Review supported productivity and workspace activity statistics. |

### Intelligent Workflows

| Technology | Description |
|---|---|
| Frame Workflows | Visual automation editor with system events, conditions and actions. |
| Frame File Rules | Automatically organize files using configurable rules. |
| Frame Profiles | Create and switch between personalized desktop environments. |
| Frame Adaptive UI | Adapt selected interface settings to the current working context. |
| Frame Shortcut Studio | Configure and manage productivity shortcuts. |
| Frame Theme Studio | Customize the appearance of FrameUI. |

### Professional Work Modes

- **Frame Focus** — distraction reduction and configurable focus sessions.
- **Frame Meeting Mode** — prepare audio devices, applications and notification settings for meetings.
- **Frame Presentation** — optimize the desktop for presentations and external displays.
- **Frame Battery Care** — provide power-management controls and battery information.
- **Frame Device Profiles** — configure behavior for supported connected hardware.
- **Frame Network Profiles** — manage network-dependent working configurations.
- **Frame Print Hub** — simplify access to printing-related functionality.

### System Management

- **Frame Safe Update** — compatibility checks and configuration protection during system updates.
- **Frame Recovery** — restore desktop settings and recover from extension-related failures.
- **Frame Diagnostics** — inspect system health, services, hardware and desktop errors.
- **Frame Report** — generate structured diagnostic and issue reports.
- **Frame Workspace Backup** — back up supported workspace configurations.
- **Frame Privacy Dashboard** — manage privacy-related system settings.
- **Frame Portable** — portable configuration and workspace management.
- **Frame Welcome** — first-run configuration and system introduction.
- **Frame App Packs** — curated optional application collections.
- **Frame Universal Install** — integrated access to supported application installation methods.

## Global Application Menu

FrameOS aims to provide a dynamic global application menu integrated directly into the desktop top bar.

The menu is designed to display real commands from supported applications, including:

- File
- Edit
- View
- Insert
- Format
- Tools
- Window
- Help

The implementation targets supported GTK, Qt, Electron and XWayland applications through available menu-export interfaces.

Applications without compatible menu-export mechanisms will retain their native menus and use a safe system-level fallback.

## Mobile Integration

Frame Connect is designed to connect the desktop with mobile devices using established technologies, including GSConnect and the KDE Connect protocol.

Planned capabilities include:

- Secure device pairing.
- Wireless file transfers.
- Clipboard synchronization.
- Device battery information.
- Mobile notifications.
- Multimedia controls.
- Remote keyboard and mouse.
- Device discovery.
- Link sharing.
- Phone-based presentation controls.
- Browser-based local sharing.
- QR code connection sessions.

Available functionality depends on the mobile platform, client application and operating system permissions. iOS integration may be more limited than Android integration.

## Application Ecosystem

FrameOS uses established Linux applications rather than unnecessarily replacing reliable software with proprietary alternatives.

### Default Applications

- Mozilla Firefox
- LibreOffice Writer
- LibreOffice Calc
- LibreOffice Impress
- LibreOffice Draw
- LibreOffice Base
- LibreOffice Math
- GNOME Files
- GNOME Settings
- GNOME Software
- GNOME Console
- GNOME Calendar
- GNOME Calculator
- GNOME Clocks
- GNOME Weather
- GNOME Maps
- GNOME Contacts
- GNOME Music
- GNOME Text Editor
- GNOME System Monitor
- GNOME Disks
- GNOME Boxes
- GNOME Connections
- GNOME Extensions
- GNOME Tweaks
- Loupe
- Papers
- Showtime
- Snapshot

The final application selection is subject to package availability and compatibility with the target distribution.

## Frame App Packs

FrameOS provides optional application collections for different professional requirements.

### Developer Pack

- Visual Studio Code
- Git
- Python Development Tools
- Node.js
- GCC and G++
- Clang
- CMake
- Meson
- Make
- GDB
- LLDB
- Rust Toolchain

### Creative Pack

- GIMP
- Krita
- Inkscape
- Blender
- Darktable
- Kdenlive
- Audacity

### Business Pack

- Thunderbird
- Business communication tools
- Advanced PDF utilities
- Project management tools
- Video conferencing applications

### Media Pack

- VLC Media Player
- OBS Studio
- Audacity

### Advanced Tools Pack

- Network diagnostics
- System administration utilities
- Advanced hardware diagnostics

Application packs are optional and require user approval before installation.

## Technical Architecture

| Component | Target Technology |
|---|---|
| Distribution Base | Ubuntu 26.10 |
| Desktop Environment | GNOME 51 |
| Desktop Interface | FrameUI |
| Display Protocol | Wayland |
| Compatibility Layer | XWayland |
| Window Manager | Mutter |
| Display Manager | GDM |
| Init System | systemd |
| Package Management | APT, DPKG, Flatpak, Snap |
| Audio System | PipeWire, WirePlumber |
| Network Management | NetworkManager |
| Graphics Stack | Mesa, OpenGL, Vulkan |
| Application Toolkit | GTK 4, Libadwaita |
| Desktop Extensions | JavaScript, GJS |
| Native Components | Python, PyGObject |
| System Communication | D-Bus |
| Local Data Storage | SQLite |
| Bootloader | GRUB2 |
| Boot Animation | Plymouth |
| Live Environment | Casper |
| Architecture | AMD64 |
| Build Automation | GitHub Actions |

Target versions are subject to upstream availability, compatibility and validation.

## Desktop Customization

FrameOS integrates selected open-source desktop customization projects:

- Open Bar
- Dash to Dock
- Blur My Shell
- Desktop Cube
- Clipboard Manager
- User Themes
- Just Perfection
- GSConnect
- AppIndicator Support
- Rounded Window Corners Reborn
- Caffeine

The visual foundation includes customized Orchis-inspired GTK styling, Fluent icons, Bibata Modern Ice cursors and Inter typography.

Extensions will be tested for compatibility, performance and stability before inclusion in release builds.

## Hardware Compatibility

FrameOS targets modern AMD64 desktop and laptop computers.

The project aims to support:

- Intel and AMD processors.
- Intel, AMD and NVIDIA graphics.
- Wi-Fi and Ethernet.
- Bluetooth devices.
- USB and USB-C peripherals.
- Compatible Thunderbolt devices.
- External monitors.
- Multi-monitor configurations.
- Laptop touchpads.
- Touchscreen devices.
- HiDPI displays.
- Fractional scaling.
- Printers and scanners.
- Webcams and microphones.
- Docking stations.
- UEFI boot.
- Secure Boot where supported.
- Suspend and resume.
- Laptop power management.

Hardware compatibility will depend on upstream Linux drivers and device-specific testing.

## Security and Privacy

Security is an essential part of the FrameOS architecture.

The project is designed around:

- Local-first storage of personal workspace data.
- Explicit permission for mobile synchronization.
- Secure device pairing.
- Application sandboxing where available.
- AppArmor integration.
- Controlled privilege escalation.
- Configuration recovery.
- Transparent system diagnostics.
- User-controlled activity history.
- Compatibility-aware updates.
- Secure upstream package sources.

FrameOS aims to provide useful automation and connectivity without unnecessary collection of personal information.

## Build and Distribution

FrameOS is planned as a real, independently branded and installable Linux distribution.

The build infrastructure targets:

- Automated ISO generation.
- Reproducible package manifests.
- Version-controlled system configuration.
- Automated compatibility checks.
- GitHub Actions integration.
- Live desktop environments.
- Virtual machine testing.
- UEFI boot validation.
- Installation testing.
- Release artifacts.
- SHA-256 integrity verification.
- Structured development changelogs.

Production releases will be published only after appropriate build and stability validation.

## Development Roadmap

FrameOS 1.0 development is divided into 15 major implementation phases.

| Phase | Development Scope | Status |
|---|---|---|
| 01 | System foundation and ISO infrastructure | Planned |
| 02 | GNOME, libraries, drivers and default applications | Planned |
| 03 | FrameUI visual foundation | Planned |
| 04 | Desktop extensions and workspace experience | Planned |
| 05 | Global Menu and Control Center | Planned |
| 06 | Branding, boot experience and installer | Planned |
| 07 | Frame Core infrastructure | Planned |
| 08 | Mobile connectivity and file sharing | Planned |
| 09 | Profiles and desktop customization | Planned |
| 10 | Projects and document management | Planned |
| 11 | Professional work modes | Planned |
| 12 | Automation and command infrastructure | Planned |
| 13 | System management and recovery | Planned |
| 14 | Welcome experience and application packs | Planned |
| 15 | Optimization, validation and release | Planned |

## The Frame Ecosystem

FrameOS represents the first operating system in a broader ecosystem designed for different computing experiences.

| Operating System | Purpose | Status |
|---|---|---|
| FrameOS | Professional work and productivity | In development |
| FrameTouchOS | Touch-oriented computing | Future project |
| FramePlayOS | Gaming and entertainment | Future project |

Current development is focused exclusively on FrameOS.

## Downloads

FrameOS is currently under active development.

Stable installation images, release notes, installation instructions and verification checksums will be made available through GitHub Releases when validated builds are ready.

Development builds should not be considered suitable for production environments or critical workloads.

## Contributing

Contributions are welcome in areas including:

- Linux distribution engineering.
- GNOME Shell extension development.
- GTK application development.
- User interface and experience design.
- System integration.
- Hardware compatibility testing.
- Performance optimization.
- Accessibility.
- Localization.
- Documentation.
- Security and stability testing.

When reporting an issue, please include the FrameOS build version, hardware configuration, reproduction steps and relevant diagnostic logs.

## Open Source and Licensing

FrameOS builds upon the work of the Linux, Ubuntu, GNOME and broader open-source communities.

Third-party software, desktop extensions, themes and libraries retain their respective licenses, copyrights and attribution requirements.

Licensing information for original FrameOS components will be provided as the project develops.

FrameOS is an independent project and is not officially affiliated with Ubuntu, Canonical, GNOME, Apple or Microsoft.

---

**FrameOS**

Designed for productivity. Engineered for flexibility. Built for the future.

*Your workspace. Your workflow. Your Frame.*
