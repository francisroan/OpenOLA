# Reddit post

I read both recent Ola research posts and followed their linked projects. They cover different parts of the scooter, so here is a short comparison and a map of our related work.

The diagnostics post reports root command execution on an S1 Pro Gen 3 through a diagnostics service. The author says root was reproduced on their test scooter, while specific effects from arbitrary CAN commands were not yet established.

The open-dashboard work is a separate experimental Gen 1 project: a replacement dashboard SDK, a community CAN reference, and a developer skill. The SDK keeps warnings and the passcode screen host-controlled, limits themes to a gated dashboard action, and keeps plugins display-only.

Our project has identified a Bluetooth security vulnerability. No technical detail is included here.

We have related project code in three forms: a Windows desktop GUI (Python), a Kotlin Android app, and the newer OpenOLA Flutter source for Android/iOS. The separate android/ project is legacy. These projects have different build and validation histories; they are not interchangeable releases.

I have prepared an OpenOLA GitHub package with the GUI and Android source/build files, a project comparison, repair findings, and a test checklist. It separates source observations from accepted requests and physical results, and identifies which app versions and platforms still need validation.

Links:
- Gen 1 dashboard SDK discussion: https://www.reddit.com/r/olaelectric/comments/1xj99i8/opensource_dash_platform_for_the_ola_s1_pro_gen_1/
- Diagnostics/root/CAN discussion: https://www.reddit.com/r/olaelectric/comments/1xhil2z/i_found_a_potential_security_vulnerability_in_the/
- Ola Dash SDK: https://github.com/abhi245y/ola-dash-sdk
- Ola CAN Reference: https://github.com/abhi245y/ola-can-reference
- Ola Dev Skill: https://github.com/abhi245y/ola-dev-skill
- Ola S1 head-unit research: https://github.com/itsmobsys/ola-s1-rea
- Ola Reverse Engineering Community: https://github.com/Ola-Reverse-Engineering-Community
- OpenOLA source package: https://github.com/francisroan/OpenOLA

Model and firmware differences matter. Please share corrections with the exact model, year, software build, and evidence type. Do not test a scooter you do not own or lack explicit permission to assess.
