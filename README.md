ingi1131-oz-project
===================

Project in the Oz language for the course INGI1131, at the Université Catholique de Louvain.

Year 2011-2012: mini Age of Empire (well-known game).

Example of quite good usage of message-passing concurrency.

The key idea, with message-passing concurrency, is to think like in Object Oriented Programming, but without inheritance (for such a project, inheritance is not needed, anyway). So, having several small objects that interact together is better than having one central and big object. It scales better: think about millions of people playing online, one central object would be a big bottleneck. So an advice: try to understand where could be bottlenecks, and avoid them.

Happy hacking for the next students ;)
