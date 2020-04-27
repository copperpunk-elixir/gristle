# Autonomous Vehicle Control - Strength in Numbers

# Elevator Pitch
"Many hands make light work." Can we achieve the robustness required for autonomous vehicle control without using expensive hardware and painstakingly-tested software? Can we mold moderately-reliable parts into an extremely reliable whole? Can we utilize the "Let it Crash" philosophy to ensure that our vehicle never does? I believe the answer is yes.

# Description

Autonomous systems present a special kind of challenge in that if an error is encountered, there might not be a user available to help remedy the situation. This is especially true with aerial applications, where the vehicle cannot simply stop and wait for someone to come press the "reset" button. Typical solutions to autonomous vehicle control consist of one or more highly reliable, well-tested, probably expensive computers running large code bases written by many people. Open-source autopilots have taken great strides towards placing autonomous vehicle control within reach for many of us, however there are few ways to improve the robustness of these systems besides further scrutinizing the code and using the best sensors available. 

With Nerves and Elixir, I believe it possible to create a decentralized clusted-based vehicle control system that can achieve sufficient levels of safety and robustness for autonomous operation, while maintaining short development cycles and an affordable price tag. I would like to discuss the work I have done towards this end, and demonstrate examples of this concept in action. Topics that could be included are:  
  * Why Nerves?
  * Node-level architecture
  * Cluster architecture
  * Modularity
  * Challenges faced and lessons learned along the way


# Notes
I started learning Elixir in September 2019 for the purpose of designing a robust, affordable autopilot and immediately fell in love. Shortly thereafter I discovered Nerves, and thus I could see a path forward for getting my autopilot on a vehicle. Since then I have been putting in time during nights and weekends and have make decent progress towards a prototype, and I have confidence that I will be able to demonstrate the full concept of my work in October. As someone fairly new to Elixir, Nerves, and functional programming, I hope to serve as an example of how easy it is to get started with this platform. 