# Quang Binh Flooding Project

A simulation project combining GAMA modeling and Virtual Reality to visualize flooding scenarios in a stylized representation of Dong Hoi city (Quang Binh province, Vietnam).

## Overview

This repository contains both GAMA modeling components and Unity VR implementation for flood simulation visualization.

## Repository Structure

- **GAMA folder**: Contains all GAMA models
  - **models/version 2/**: Contains the three main GAMA models:
    - `Flooding Model.gaml`: Base simulation model
    - `Flooding UI.gaml`: Desktop UI version for testing and demonstration without VR
    - `Flooding VR.gaml`: VR version that works with the Unity project
- **URP Quang Binh v2**: Unity project for VR visualization

## Screenshots

![GAMA Simulation Interface](https://github.com/user-attachments/assets/99778a25-3816-4165-ace3-c6cae5cea835)

![VR Visualization](https://github.com/user-attachments/assets/b2b561d4-194d-4c4b-b2b4-be7580547d8d)

## Setup and Usage

### GAMA Setup
1. Install [GAMA Platform](https://gama-platform.org/)
2. Install the [SIMPLE Plugin for GAMA](https://github.com/project-SIMPLE/simple.toolchain/tree/Unity-6/GAMA%20Plugin)
3. Open the GAMA folder as a project
4. Navigate to models/version 2 to access simulation models

### Unity VR Setup
1. Open the URP Quang Binh v2 folder in Unity
2. Ensure you have the appropriate VR hardware connected
3. Build and run the project for VR visualization

## Model Descriptions

- **Flooding Model.gaml**: Core simulation logic for flood dynamics
- **Flooding UI.gaml**: Enhanced UI for desktop exploration with parameter adjustment capabilities
- **Flooding VR.gaml**: Specialized version with VR-optimized data export for Unity integration