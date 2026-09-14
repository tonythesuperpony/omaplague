# Omaplague

A strategic global pandemic simulation game built in **Godot 4.3**, inspired by *Plague Inc.*

---

## Features

### 1. Pathogen Types
- **Bacteria**: The standard, balanced pathogen with resilient base defenses.
- **Virus**: Unstable genetic structure that spontaneously mutates symptoms for free. Devolving traits costs DNA.
- **Fungus**: Spores travel slowly across borders, but unlocks the special **Spore Burst** ability to instantly seed new random countries.
- **Parasite**: Highly stealthy organism with minimized severity that avoids human detection.
- **Nano-Virus**: Escaped microscopic laboratory weapon. Humanity begins researching a cure immediately on Day 1!

### 2. Difficulty Modes
- **Casual**: Sick people are hugged. Nobody washes hands. Doctors work 3 days a week. Cure research is sluggish.
- **Normal**: Compulsory hygiene. Sick people are ignored. Standard medical response.
- **Brutal**: Compulsive hygiene. Sick people are quarantined immediately. Doctors work 24/7. Airports and ports shut down rapidly.
- **Mega-Brutal**: Genetic drift escalates evolution costs. Frequent medical checks. Relentless global cure efforts.

### 3. World & Country Database
- **44 Balanced Global Regions** covering all 7.25+ billion humans on Earth.
- Real demographic and environmental traits for every region:
  - **Climate**: Cold, Hot, Balanced
  - **Humidity**: Arid, Humid, Balanced
  - **Density**: Urban, Rural, Balanced
  - **Wealth**: Rich, Middle, Poor
  - **Transit Network**: Dynamic airports, maritime seaports, and land connections.
- Dynamic port closures: Countries close airports, seaports, and seal land borders as infections and deaths surge.

### 4. Evolution Tech Trees (37+ Upgrades)
- **Transmission**: Birds 1 & 2, Air 1 & 2, Water 1 & 2, Extreme Bio-Aerosol, Rodents 1 & 2, Livestock, Insects, Blood.
- **Symptoms**: Nausea, Coughing, Rash, Insomnia, Sneezing, Cysts, Vomiting, Fever, Skin Lesions, Pulmonary Edema, Necrosis, Dysentery, Total Organ Failure, Coma.
- **Abilities**: Cold Resistance 1 & 2, Heat Resistance 1 & 2, Environmental Hardening, Drug Resistance 1 & 2, Genetic Hardening 1 & 2, Genetic Reshuffle 1 & 2 (resets cure progress).

### 5. Interactive World Map & Visuals
- High-definition dark command center world map texture with latitude/longitude graticules.
- **Pixel-perfect country selection** via color-indexed hit mask.
- Glowing, pulsating red infection halos and blood-tinted cores that dynamically expand with infection and mortality rates.
- Animated airliners and cargo ships traversing curved flight paths and ocean lanes between countries.
- Interactive floating bubbles:
  - **Red Infection Bubbles**: Pop when a new country is infected.
  - **Orange DNA Bubbles**: Pop to harvest bonus DNA points.
  - **Blue Cure Bubbles**: Pop to delay and sabotage cure research breakthroughs.
- Mouse pan (right-click / middle-click drag) and zoom (mouse wheel).

### 6. Procedural Audio Effects
- Synthesized 16-bit audio sound effects:
  - Bubble pops, sparkling DNA reward chimes, biological evolution pulses, biohazard alert pings, cure warning sirens, victory and game-over musical chords.

---

## How to Run

Launch the game with Godot 4:
```bash
godot
```
Or run directly from the project directory:
```bash
cd ~/Projects/omaplague
godot scenes/main.tscn
```
