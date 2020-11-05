# In the beginning, there was the middle...

You're jumping into a novel at about Chapter 6. And no, that's not because you missed the earlier chapters. I am only writing it now, because I think it has finally become something worth reading about. There will be plenty of pictures, I promise.<br><br>
This project started out as somewhat of an experiment, or rather, it was a means to scratch an itch that had been bothering me for a few years:
>What does it take to make an autopilot sufficiently reliable, affordable, maintanable, and integratable enough to be extremely useful?

Or written as more of a challenge:<br>
> Can I create an autopilot that I could trust, afford, and would actually want to use?

It's basically a rework of the *fast-cheap-good* triangle. I know plenty of autopilots that can satisfy one or two of those requirements, but I haven't found one that really fits all three. But even this challenge isn't really compelling, because who cares if somebody "wants to use" a device? The real question is, what are they going to do with it? So let's make the final target something like this:
> Can we create an autopilot that someone else could trust, afford, and easily use to do something really interesting?

You may notice that the pronoun has changed from "I" to "we". Well, yeah, to do this right I will need some help. Therefore I will continue to use "we", even though at the moment it is still just I. Oui? Aye.<br>
## The Brett Factor
Here's the thing: ***everyone needs a Brett***  
My Brett is probably the nicest person this side of the Rockies. He also happens to be brilliant. He also might not like being referred to as "my Brett", so I'm leaving his last name out of this. (Sorry Brett)<br>

Now Brett happens to be a fan of the [Elixir](https://elixir-lang.org/) programming language. I had never even heard of it before, but he thought its robustness and fault-tolerance might make it a suitable candidate for an autopilot. When I looked into the language and the BEAM operating system upon which it ran, I was convinced as well. After learning about Elixir, I came across the [Nerves proect](https://hexdocs.pm/nerves/getting-started.html). Nerves is essentially embedded Elixir capable of running on cheap single-board computers (Raspberry Pis, BeagleBoards, etc). The Nerves core team is fantastic, and the community is extremely friendly. If network-capable embedded devices interest you, I highly recommend you check it out.<br>

I will spare trying to convince you why Elixir is a great language for creating an autopilot. After all, you couldn't argue back, so it would make for a pretty lousy debate. But let me at least tell you why I found it appealing:<br>
* Elixir is built on top of Erlang, which was designed by the Ericsson Computer Science Laboratory to be EXTREMELY reliable
* Nerves allows Elixir to be run on very affordable hardware
* Elixir coupled with affordable hardware means we can have an autopilot consisting of several, smaller nodes, thereby adding redundancy without sacrificing capability (assuming we do it right)
* An autopilot that is designed to operate as a decentralized cluster can more easily adapt to the requirements of the vehicle or mission (add/subtract nodes, sensors, etc.)
* If nodes can be easily added, then third-party hardware can be integrated with the autopilot via an API.
* If this hardware is smart, it can pilot the vehicle by means of high-level commands (speed, course, altitude), or it can provide environmental data to the autopilot's map/navigation system (obstacles, other vehicles, geofences, etc.). This is because all nodes are (almost) equal in the eyes of the cluster. A command can have several sources, with the highest priority one taking precedence.
* If commands are designed to come from anywhere inside the vehicle, then they can also come from outside the vehicle. Hello SWARM!
* Those last two bullet points...are you excited? I'm excited. I bet Brett is excited. He's an energetic dude.  

With these statements as my guide and motivation, I set out to build a robust, decentralized, expandable, maintable autopilot set atop the Erlang/Elixir/Nerves platform. If anything about this interests you, please stick around for more of the journey.<br>

-Greg
