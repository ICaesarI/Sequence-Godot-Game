# 🎴 Sequence-Godot: Multiplayer Engine

### High-Performance Board Game Logic & Godot 4 Networking
This repository provides a robust, production-ready implementation of the classic **Sequence** board game. Built with **Godot 4.x**, it features an authoritative networking architecture, optimized UI synchronization, and a clean "Minimalist Dark" aesthetic.

---

## 🚀 1. Quick Start (Development)

Follow these steps to deploy the environment and run a local multiplayer test. The project is pre-configured for rapid debugging.

### Prerequisites
* **Godot Engine 4.2+** (Standard or .NET version).
* **Git** for version control.

### Installation & Run
| Step | Action | Command |
| :--- | :--- | :--- |
| **1** | Clone the repo | `git clone https://github.com/ICaesarI/Sequence-Godot-Game.git` |
| **2** | Enter directory | `cd Sequence-Godot-Game` |
| **3** | Launch Project | Open `project.godot` with Godot Engine |
| **4** | Multi-Instance | Set `Debug > Run Multiple Instances > 2 Instances` |

---

## 🎲 2. Core Game Systems

### 🛠 A. Authoritative Networking
* **Server-Side Logic:** The Host manages the deck, shuffles, and validates move legality.
* **RPC Synchronization:** High-reliability Remote Procedure Calls (RPCs) handle chip placement and turn transitions.
* **State Integrity:** Prevents "double-play" or out-of-turn moves via server-side validation.

### ⚡ B. Gameplay Features
| Feature | Description |
| :--- | :--- |
| **Fog of War** | Opponent cards are hidden (back-side) to ensure strategic integrity. |
| **Sequence Detection** | Algorithmic check for 5-in-a-row (Horizontal, Vertical, Diagonal). |
| **Dynamic Hover** | Visual feedback system that highlights card-to-slot matches on the board. |
| **Normalization** | Automated Uppercase formatting for Room Codes and Player IDs. |

### 🎨 C. Visual Identity
* **Minimalist Aesthetic:** Clean UI focusing on readability and smooth transitions.
* **Vector Icons:** SVG-based chips and cards for infinite scaling without quality loss.
* **Turn Indicators:** Real-time UI updates showing the active player's color and status.

---

## 📂 3. Project Structure

```text
Sequence-Godot-Game/
├── 📁 Assets/
│   ├── 📁 Background/        # High-quality textures (Denim, Velour, Poplin)
│   ├── 📁 Cards/             # Card Atlas textures
│   ├── 📁 Chips/             # Flat style chips (Black, Blue, Green, Red, etc.)
│   └── 📄 new_style_box_flat.tres
├── 📁 Scenes/
│   ├── 🎬 Main.tscn          # Game world & Network entry point
│   ├── 🎬 MainMenu.tscn      # Lobby & Connection UI
│   ├── 🎬 CardHand.tscn      # Player's interactive hand
│   ├── 🎬 Slot.tscn          # Board slot logic
│   └── 📜 HUDManager.gd      # UI & HUD controller
├── 📁 Scripts/
│   ├── 📁 Autoload/          # Global Singletons
│   │   ├── 📜 BoardData.gd   # Board configuration & slot mapping
│   │   ├── 📜 CardAssets.gd  # Card texture loading & management
│   │   ├── 📜 GameManager.gd # Main game state & turn logic
│   │   └── 📜 MultiplayerManager.gd # ENet & RPC handling
│   ├── 📜 Main.gd            # Main game loop controller
│   ├── 📜 CardHand.gd        # Interactive hand logic
│   ├── 📜 Deck.gd            # Deck shuffling & distribution
│   └── 📜 Slot.gd            # Slot interaction & chip placement
├── 📄 project.godot          # Godot project settings
└── 📄 README.md              # Technical Documentation
```
---

## 📊 4. Network Aliases & Signals

The engine uses a centralized signal bus to keep the UI decoupled from the logic:

| Signal / Method | Context | Function |
| :--- | :--- | :--- |
| `on_card_played` | **Local** | Triggers hand animation and sends move to Server. |
| `sync_chip_placed` | **RPC** | Replicates the chip on all connected clients. |
| `update_turn` | **Global** | Updates UI banners and enables/disables input. |

---

## ⚠️ Important Note on Multiplayer

To test online outside of your local network, ensure **Port Forwarding** (default ENet port) is configured or use a tunneling service like **Ngrok** or **Tailscale** to expose your local host to your friends.

---

## 📧 Contact & Contributions

Feel free to reach out for collaboration or reporting bugs:

* **LinkedIn:** [Cesar Gonzalez](https://www.linkedin.com/in/cesar-gonzalez-anayadev) | [Cristian Lona](https://www.linkedin.com/in/cristian-josue-lona-avalos-3411b2218)
* **GitHub:** [ICaesarI](https://github.com/ICaesarI) | [CristianLona](https://github.com/CristianLona)
* **Email:** [cesar.gonzalez.anayadev@gmail.com](mailto:cesar.gonzalez.anayadev@gmail.com) | [cristianlonavalos@gmail.com](mailto:cristianlonavalos@gmail.com)

---

