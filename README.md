# Take-home assignment

*FUTURE TRASH studio, programmer position, 11/18/2025*

## **Introduction**

The purpose of this take home assignment is to assess your programming capabilities with a 1-2 hour task. 

## Rules

The work has to be done with Rojo & in a public repository with the commit history viewable. The game needs to be buildable. Allowed to use any libraries you wish as long as it’s specified in the repository. **Try your best to keep commits incremental, instead of one large one.**

## Task

**Create a baggage conveyor belt**

- Bags get spawned in
    - Bags get spawned in automatically at the start of the conveyor
        - Bags get spawned in every x seconds
            - Default interval 1 per second
                - This variable should be controllable with a UI slider
                    - Assign this UI only to one person in the server, can be random, can be first, doesn’t matter
    - There need to be a spawning in animation for the bags
        - there’s no specified way to do this, under your discretion
- The baggage conveyor belt always moves bags forward
    - Baggage conveyor length is 50 studs long
    - Bags at the end of the conveyor get deleted
        - Bags should have an animation for being deleted
            - there’s no specified way to do this, under your discretion
- Bags are unique
    - When the client clicks on the bag, server & client both print the part’s ID
    - Each bag should spawn with a random material & colour assigned to it
        - Each player should see the same material & colour on a bag as everyone else (clients need to be in sync)

Please also include an explanation of your approach to this task & why you chose to do it in this particular way and not in another if possible.

Please reach out of there are any questions.

## Criteria

The task will be judged by your approach to creating this in terms of optimization & understanding of the task at hand. 

*The ideal network performance is less than 4KB/s average, when all the bags are spawned in.*