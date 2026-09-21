<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Backup UART RX/TX PHYs with configurable clock and baud rate, 8N1 byte streams, and back-to-back transmit frames. RX includes input synchronization, optional glitch filtering (enabled by default), start-bit validation, and framing/overflow error pulses. Packet framing remains the responsibility of the packet layer.
- Self-checking UART simulation under `verif/uart/` across clock and filter configurations, integrated into `make regression` and CI, with independent TX waveform and RX stimulus checks.
