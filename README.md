<h1 align="center">XB950 Control for macOS</h1>

<p align="center">
  A native macOS controller for the Sony MDR-XB950N1.
</p>

XB950 Control is a native SwiftUI application for the Sony MDR-XB950N1. It
connects directly to Sony's private Bluetooth Classic RFCOMM service—no helper
daemon, command-line tool, or internet connection is required.

## Features

- Connect to a paired MDR-XB950N1
- Read battery and charging state
- Enable or disable noise cancelling
- Set CLEAR BASS from −10 to +10
- Select every Surround (VPT) preset
- Read the model, firmware, and MDR protocol version
- Menu bar controls for battery, noise cancelling, and CLEAR BASS
- Native macOS 26 SwiftUI interface with Liquid Glass surfaces
- Universal Release builds for Intel and Apple silicon

## Requirements

- macOS 26 or later
- Xcode 26 or later
- Sony MDR-XB950N1 already paired in System Settings

The app has been designed for macOS 26. The Bluetooth transport itself uses
Apple's native IOBluetooth framework and contains no third-party dependencies.

## Build

1. Open `XB950Control.xcodeproj` in Xcode 26.
2. Select the **XB950Control** scheme and **My Mac**.
3. Press **Run**.
4. Allow Bluetooth access when macOS asks.

No signing configuration is committed. For a local build, select your Personal
Team under **Signing & Capabilities**, or disable signing for a one-off Debug
build. Release archives use Xcode's standard architectures, producing both
`arm64` and `x86_64` slices.

## Pairing and connection

Pair the headphones in **System Settings → Bluetooth** first. The app lists
paired MDR-XB950N1 devices. If they do not appear, make sure the headphones are
on, click **Open Bluetooth Settings**, pair them, then click **Refresh**.

Only one controller app should have Sony's RFCOMM service open at once. Close
Sony Headphones Connect on a nearby phone if the Mac cannot open the control
channel.

## Distribution

For a public downloadable build, use **Product → Archive**, then distribute a
Developer ID–signed and notarized app. Never publish a build signed with a
personal development identity.

## Protocol

The implementation is intentionally model-specific. The Sony service UUID is
`96CC203E-5068-46AD-B32D-E316F5E069BA`. Frames are escaped and checksummed, and
incoming command frames are acknowledged as required by the MDR v1 protocol.
The packet map is documented in [`docs/protocol.md`](docs/protocol.md).

The BASS EFFECT hardware master state is not exposed because firmware 1.0.3
does not report it reliably. CLEAR BASS level control does work independently.

## Privacy

The app communicates locally with a paired Bluetooth device. It has no
analytics, telemetry, accounts, or network code.

## Contributing

Bug reports and pull requests are welcome. Hardware reports should include the
headphone firmware version, Mac model/architecture, and relevant Console logs,
but never unrelated system logs or personal Bluetooth device details.

## Licence

MIT. This project is unofficial and is not affiliated with or endorsed by
Sony. Sony and MDR are trademarks of Sony Group Corporation.
