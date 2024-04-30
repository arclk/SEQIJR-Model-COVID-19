# SEQIJR Model Project for Studying the COVID-19 Epidemic

## Description
This project is a NetLogo implementation of the SEQIJR (Susceptible, Exposed, Quarantined, Infected, Isolated, Removed) epidemiological model for studying the evolution of the COVID-19 epidemic. The model allows simulating the effect of various containment measures, such as lockdown, social distancing, mask usage, and contact tracing.

## Requirements
- NetLogo 6.2.2 or later

## Usage
1. Open the `model.nlogo` file with NetLogo.
2. Set the desired parameters for the simulation, such as the world size, initial number of people, infection probabilities, and exposure, infection, and recovery times.
3. Press the "Setup" button to initialize the simulation.
4. Press the "Go" button to start the simulation.
5. During the simulation, you can apply various containment measures using the provided controls in the NetLogo user interface.
6. The plots show the evolution of the simulation, including the number of susceptible, exposed, infected, and removed people.
7. You can export the adjacency matrix of contacts to visualize the graph of possible infections using the `visualize.nlogo` model.

## Project Structure
- `model.nlogo`: The main file containing the implementation of the SEQIJR model in NetLogo.
- `visualize.nlogo`: An auxiliary model to visualize the graph of possible infections from the exported adjacency matrix.
- `Report.pdf`: A detailed report describing the model, implementation, and experimental results.

## Credits
This project was developed by Alberico Arcangelo for the Complex Systems and Network Science course at the University of Bologna.
