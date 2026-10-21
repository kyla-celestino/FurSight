_Checked by ABDoria on May 29, 2026_

# FurSight: A Mobile App for Geotagged Sighting and AI-Based Identification of Campus Cats and Dogs

## Authors
**Kyla Cristine M. Celestino**  
BS Computer Science, Institute of Computer Science  
University of the Philippines Los Baños

**Adviser:** Asst. Prof. Ariel B. Doria  
Institute of Computer Science, UPLB

---

## Abstract

Monitoring campus animals in university settings has become increasingly relevant as stray and resident cats and dogs become part of the community's daily environment. This study presents FurSight, a community-driven mobile application for the geotagged sighting and AI-based individual re-identification of campus cats and dogs at the University of the Philippines Los Baños (UPLB). FurSight enables users to submit geotagged photo sightings, which are processed on-device through a two-stage AI pipeline: a YOLOv8n model for animal detection and classification, and an EfficientNet-B0 model with cosine similarity matching for individual re-identification. Detected sightings are stored in a Firebase backend and visualized through a real-time heatmap. The detection model achieved a mean Average Precision at IoU 0.50 (mAP@0.5) of 0.9944, with precision of 0.9931 and recall of 0.9848. The re-identification model achieved an overall similarity accuracy of 0.9401, with same-animal pair accuracy of 0.9144 and different-animal pair accuracy of 0.9658. Usability was evaluated using the System Usability Scale (SUS) with 20 respondents from the UPLB community, yielding a mean SUS score of 83.88, which falls in the "Excellent" grade range. These results suggest that FurSight provides a usable and technically viable solution for community-based campus animal monitoring.

---

**Keywords:** Animal re-identification, campus animals, citizen science, Flutter, geotagged sighting, heatmap, mobile application, YOLOv8n, EfficientNet-B0
