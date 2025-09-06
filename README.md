# Advanced Charging Controller (ACC)

---
## Support Me / Sponsorship

If you like my work, you can support me on these platforms:

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Donate-orange?logo=kofi&style=for-the-badge)](https://ko-fi.com/ian7672)  
[![Trakteer](https://img.shields.io/badge/Trakteer-Donate-red?style=for-the-badge)](https://trakteer.id/ian7672)  

---
---

## Enhanced by github.com/Ian7672

- Stop charging: 90%
- Resume charging: 80%
- Idle mode: 90%
- Safe shutdown minimum: 2%
- Overheat: only warning, safe up to 55 °C
### 🔔 Notifications
- When charger is connected → "🔌 Charger connected"
- When idle/charging paused (90%) → "⏸️ Charging paused at 90%"
- When charging resumes at 80% → "▶️ Charging resumed"
- When battery temperature ≥45 °C → "🌡️ Battery warm"
- When battery temperature ≥55 °C → "⚠️ Battery temperature has reached 55 °C!"
- When idle mode is active (90%) → "🛑 Idle mode enabled"
- When battery level <20% → "📉 Battery low" (once per level, reset on unplug)
- No forced shutdown when battery is hot → safe for long-term use


This module is based on [VR-25/acc](https://github.com/VR-25/acc) and further enhanced by [Ian7672/acc-magisk-module](https://github.com/Ian7672/acc-magisk-module).

---

## Practical & Technical Battery Guide

**1. Lithium-Ion Battery Basics**: Anode (graphite), cathode (NMC/LCO/LFP), electrolyte, separator. SEI layer forms on anode, stabilizes battery but excessive growth reduces capacity. Aging factors: temperature (most critical), charge cycles, SoC during storage, fast charging (heat).

**2. Degradation Mechanisms**: SEI growth, electrode cracking, electrolyte breakdown, increased resistance, calendar aging (high SoC/high temp storage).

**3. Charging Phases**: CC (Constant Current): fast initial charge. CV (Constant Voltage): near full, voltage held, current drops, more stress. Frequent 100% charging keeps battery in CV phase longer, accelerates aging.

**4. SoC & Cycles**: Top-up charging (20–80%) is healthier than deep discharge (0–100%). Avoid 0% and 100% when possible.

**5. Practical SoC Recommendations**: Storage: ~40–60% (ideally 50%), recharge every 3–6 months, store cool/dry. Daily use: 20–80% or 30–90%. Full charge OK for travel, but don't leave full for long.

**6. Temperature Management**: Ideal: 15–25°C (storage), 20–35°C (use/charge). High temp (>40°C): faster aging, swelling risk. Low temp (<0°C): don't charge, risk of lithium plating.

**7. Charging While In Use**: Main risk: heat stacking. Reduce load, ventilate, use quality charger/cable, let cool if hot (>40°C).

**8. Fast Charging**: Convenient but increases heat and aging. Use occasionally, prefer slow charging for daily use.

**9. Powerbank Use**: Prefer quality powerbanks with protection. Passthrough increases heat, shortens lifespan.

**10. Charger Bypass / Power-Path**: Modern devices may route power directly to system, reducing battery stress during heavy use.

**11. Daily Checklist**: Store at ~50% for long-term. Top-up charging is healthier than routine 0→100%. Avoid heat, use quality accessories, enable charge limit if available. Replace swollen batteries at authorized service.

**12. FAQ**: Overnight charging to 100% is OK sometimes, but not every night. Frequent top-ups are better than deep discharge. Powerbank can damage battery if poor quality or excessive heat. Wait for device to cool before charging if hot. Bypass mode is generally safe if implemented correctly.

**13. Troubleshooting**: Rapid capacity drop: check temperature, charging habits. Swelling: stop use/charging, replace battery. Overheat: unplug, let cool, check for background apps/case. Inaccurate SoC: recalibrate occasionally (charge to 100%, discharge to ~5–10%, recharge).

**14. Example Scenarios**: Daily use: charge overnight to 80%, top-up as needed, avoid heavy use while charging. Storage: set to 50%, turn off, store cool, recharge every 3 months. Continuous use: use bypass/preserve battery if available, limit SoC to 50–60% if battery not needed.

**15. Takeaway**: Temperature > SoC > current — order of importance for battery life. Store at ~50% for long-term. Top-up charging (20–80%) is healthier than routine 0→100%. Avoid heat, use quality accessories, enable charge limit if available. Bypass charger is good if properly implemented.

---

## Download Latest Release

[![Download Latest Release](https://img.shields.io/badge/Download-Latest%20Release-brightgreen?style=for-the-badge)](https://github.com/Ian7672/acc-magisk-module/releases/latest)

---

## DESCRIPTION

ACC is an Android software for [extending battery service life](https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries) by controlling charging current, temperature, and voltage. This module is compatible with any root solution and installs systemlessly.

## LICENSE

Copyright 2017-2023, VR25
GPLv3 — see <https://www.gnu.org/licenses/>.

## DISCLAIMER

Use at your own risk. The author assumes no responsibility for any damage or issues caused by use/misuse. Always use official links.

## WARNINGS

ACC modifies low-level kernel parameters to control charging. Some devices (e.g., Xiaomi Poco X3 Pro) may have hardware quirks. Use auto shutdown to avoid deep discharge. See [XDA post](https://forum.xda-developers.com/t/rom-official-arrowos-11-0-android-11-0-vayu-bhima.4267263/post-85119331) for details.

## PREREQUISITES

- Android or KaiOS
- Any root solution (KernelSU, Magisk, SuperSU, etc)
- Busybox (if not using KernelSU/Magisk)

## QUICK START

1. Flash the zip or use a front-end app (requires root).
2. Default config is safe for most users. Use `acc` wizard for setup.
3. For issues, see troubleshooting below.

## SETUP/USAGE

The `acc` command is a built-in wizard. Run it for an interactive setup.

Alternatively, use a front-end app like AccA.

### Essential Terminal Commands

- `acc`: Launches the setup wizard.
- `accd`: Starts/restarts the ACC daemon.
- `accd.`: Stops the ACC daemon.
- `acc [pause] [resume]`: Quickly set pause and resume capacities. Example: `acc 80 75` pauses at 80%, resumes at 75%.
- `acc -s c [mA]`: Set max charging current. Example: `acc -s c 500` sets a 500 mA limit.
- `acc -s v [mV]`: Set max charging voltage. Example: `acc -s v 4100` sets a 4100 mV limit.
- `acc -s s`: Manually select and enforce a charging switch.
- `acc -t`: Test all available charging switches to find working ones.
- `acc -l`: View the ACC daemon log for debugging.
- `acc -u`: Upgrade ACC to the latest version.

For the full list of commands, run `acc --help`.

## TROUBLESHOOTING

### Charging Switch Issues
By default, ACC automatically selects a charging switch. If charging doesn't pause/resume correctly, run `acc -t` to test switches. Then, use `acc -s s` to manually enforce a reliable switch from the list.

### Slow Charging
Can be caused by:
- Setting a low current limit (`maxChargingCurrent`).
- The cooldown cycle being active. Adjust `cooldownRatio` (e.g., `(50 10)`) or `cooldownCurrent`.
- A problematic charging switch. Try enforcing a different one.

### Daemon Stopped (accd)
Check the log with `acc -l`. A common reason (exit code 7) is all automatic charging switches failing. Solve this by manually enforcing a working switch with `acc -s s`.

### Battery Level (%) Seems Wrong
Some devices have a discrepancy between the kernel and Android's reported capacity. Enable `capacity_sync=true` or `capacity_mask=true` in the config to sync them.

### Logs and Diagnostics
Run `acc -le` to export all logs to a `.tgz` file in your `/sdcard/Download/` folder. This is useful for reporting issues.

## FREQUENTLY ASKED QUESTIONS (FAQ)

**Q: How do I report an issue?**
**A:** Provide detailed information and attach the logs generated by `acc -le` right after the problem occurs.

**Q: Does ACC work when the phone is off?**
**A:** No, it requires Android to be running. It does work in some custom recoveries.

**Q: What is "idle mode"?**
**A:** A state where the device runs directly off the charger, bypassing the battery, reducing wear. Not all devices support native idle mode. Emulated idle mode can be achieved by setting voltage limits (e.g., `acc 3900`) or setting `resume_capacity` very close to `pause_capacity` (e.g., 80 and 79).

**Q: How to set day/night profiles?**
**A:** Use the built-in scheduler. Example to set a night profile that activates at 10 PM:
`acc -c a ": at 22:00 acc -s pc=50 mcc=500 mcv=3900; acc -n 'Night profile activated'"`

## LINKS & REFERENCES

- [Original Project (VR-25/acc)](https://github.com/VR-25/acc)
- [Ian7672's Enhancement](https://github.com/Ian7672/acc-magisk-module)
- [Battery University - Prolonging Lithium-based Batteries](https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries)
- [Frontend App (AccA)](https://github.com/MatteCarra/AccA/releases)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/module-magic-charging-switch-cs-v2017-9-t3668427)
- [Telegram Support Group](https://t.me/acc_group)
