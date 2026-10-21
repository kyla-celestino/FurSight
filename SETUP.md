# SETUP.md — FurSight

## Overview
FurSight is an Android mobile application for geotagged sighting and AI-based individual re-identification of campus cats and dogs. All AI inference runs fully on-device using TFLite models.

---

## Requirements
- Android device running **Android 9.0 (Pie) or higher**
- Camera and location permissions must be granted on first launch
- Internet connection required for Firebase sync and heatmap

---

## Installation

### Option 1: Install via APK (Recommended)

The Google Drive folder below contains the APK installer, a demo video, and the user manual.

**Google Drive:** https://drive.google.com/drive/folders/1wpvvsbjDFKxSRSj7kNOz4v8PLLSABaHT?usp=sharing

The folder contains:
- `FurSight.apk` — application installer
- `FurSight_Demo.mp4` — demo video of the application
- `FurSight_UserManual.pdf` — user manual

**Steps to install:**
1. Download `FurSight.apk` from the Google Drive link above onto your Android device
2. Open your device **Settings → Security** (or **Privacy**) and enable **Install from unknown sources**
3. Open the downloaded APK file and tap **Install**
4. Once installed, open FurSight and register an account to get started

> **Note:** The "unknown sources" setting may vary by device manufacturer. On some devices it appears as "Install unknown apps" under the specific browser or file manager you used to download the APK.

---

## Application Features
- **Sighting Submission** — capture or upload a photo to trigger the on-device AI pipeline
- **Community Feed** — browse geotagged sightings submitted by all users
- **Heatmap** — view sighting density across the UPLB lower campus
- **Animal Profiles** — browse identified campus animals and their sighting history
- **Submission Logs** — review your own past submissions

---

## AI Pipeline
| Stage | Model | File | Size |
|---|---|---|---|
| Detection | YOLOv8n (int8) | `detect.tflite` | 3.08 MB |
| Re-identification | EfficientNet-B0 | `reid.tflite` | 9.22 MB |

Both models are bundled inside the APK and run entirely on-device — no API calls are made for inference.

---

## Notes
- Photos should be taken between **8:00 AM and 5:00 PM** for best detection accuracy
- The animal should be clearly visible and fill most of the frame
- Re-identification accuracy improves as more sightings are submitted over time
