# SIR Model 

![](./SIR.png "SIR Model")

This folder contains the SIR model files for both NetLogo and Python model versions. 

1. NetLogo SIR model - NetLogo-based networked SIR model used to demonstrate the mechanics of disease spread across a social network. Replaced by the Python Mesa model for performance and compatibility reasons.
   Files:
   - Virus on a Network LATTICE - uses a square lattice network with von Neumann neighborhood
   - Virus on a Network LATTICE8 - uses a square lattice network with Moore neighborhood (additional diagonal connections)
   - Virus on a Network SW FAST - uses a Watts-Strogatz small-world network
   
3. Mesa SIR model - Python-based networked SIR model used to demonstrate the mechanics of disease spread across a social network. Contains both interactive and batch version of the model.
   Files:
   - model.py - the main simulation file
   - agents.py - the agent behavior file
   - app.py - original Mesa simulation file
   - app_notebook.ipynb - modified interactive simulation file
   - app_headless.ipynb - modified batch simulation file
