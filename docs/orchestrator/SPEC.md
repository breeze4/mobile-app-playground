Goal:
I am building a very lightweight orchestration layer for a mobile app migration project. Basically building an iOS app from scratch but using an existing iOS app project as the blueprint and the goal is "drop-in replacement with full parity", which means careful and rigorous approach to writing tests for how existing features work. This project dir has an Android app in it because this iOS project is for work on my Mac, but I am on windows on my personal PC so I can only do Android.

This is an ambitious project and the only way to succeed is to create a very simple system to help organize the work and build it.

The orchestrator will use:
git
beads + beadsui (bdui) for task tracking
Claude code skills/agents/commands
Ralph loops for autonomous work
Lightweight MD/HTML based reporting mechanism with screenshots/videos of e2e test runs showing a feature/slice (ideally store the output of a slice build-out in markdown and then have a way to open that MD in a simple HTML/JS app that shows the text in the HTML template and has the videos/screenshots/etc)

Building agentic work orchestrator from scratch:
- Research modules -> create plans, review plans with codex, create e2e tests for the existing app, port feature to new app
- Beads UI for seeing the status of items and verifying what was done
- Need a post-build report on each feature or module (slice?), should include a description, screenshots, etc - basically a PR, but not asking for approval
	- Record e2e test runs and have screenshots
	- Show the e2e trace as an expandable type thing with a timestamp taking you to that spot in the video
- This should be in a simple HTML report format, with artifacts stored in a simple directory structure in the parent project
- Ralph loops setup for overnight work - figure out whether to do a broad pass of "all of this kind of work" or do a full feature slice at a time
- Vertical slices and horizontal slices - divide the modules up into that, probably 150-200 of them
- Need a slice visualizer or diagrams as well

Turn all of these orchestration creation steps into beads, en masse, and hook beads into git
	- Harness for creating slice plans, each "create plan for slice X" is a bead
		- Break the project into 100+ slices, do this manually, only has to happen once, relies on architectural decisions
		- Agent/skills for creating a slice plan
		- Given 100+ slice definitions, parallelize slice plan creation and checking against codex dual-loop
	- Structured bead creation for slice plans, should have N=100+ plans that each have sub-beads for K steps: research, plan, test plan, implement, verify, report -> end up with  NxK beads
	- Test plan consists of:
		- What kinds of tests to be used
		- What are the behavioral test cases in plain English or simple descriptions, given/when/then and assertions/expectations
	- Beads could be assigned to an agent type, so create those agent types for: slice planner + all the rest of the slice agents
		- Same read-only (research, test plan) step types for different slices can be done at the same time, but there is a dependency between overall slices; don't parallelize in general unless the work is too large to do
	- Creating the report to go with the PR is an agent step, but also make sure all e2e tests and other parts are done with reporting in mind, recording video/screenshots etc
		- Break this into all the slice creation steps 
	- Ralph loop builder/recommender:
		- Find auto loops within the project that can be run, by analyzing the beads structure, can initiate long running loops that will work through slices in serial
		- Have this generate the Ralph plan based on the beads - don't try to do the entire app at a time, it should be broken down into logical phases where an important feature set is built out across multiple slices and has specific ordering requirements
	- Use existing plans and research as a starting point, but need to create the harness to plan and track the work, and to facilitate order of implementation
	- Bottleneck is simulator time, I think. Need to spend it wisely, but 24/7 will

Git + Beads Integration:
	- Every bead completion results in a git commit
	- Use scripts/bd-done.sh to commit and close in one step: bd-done <bead-id> -r "reason"
	- Commit message includes bead title and ID (Closes: <bead-id>)
	- prepare-commit-msg hook adds agent identity trailers
	- Agent prompt instructions must include: "commit changes then close the bead using scripts/bd-done.sh"
	- No git push — single machine, single person project. All work stays local.