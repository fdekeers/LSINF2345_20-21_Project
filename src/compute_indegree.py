import matplotlib.pyplot as plt
import os

xaxis = [i for i in range(1, 11, 1)]  # Default x-axis
cycles = [i for i in range(0, 181, 20)]  # Axis with the cycles number

for file in os.listdir("../results"):
    policy = file.split('.')[0]  # Name of policy
    listDictForIndegree = [{} for i in range(10)]
    with open("../results/"+file, "r") as f:
        # Loop through the lines of the result file, to count the links
        for line in f:
            #format: Cycle;NodeID;[PeerID1,PeerID2,....]
            parts = line.strip().split(";")
            if int(parts[0])%20 == 0:
                for j in parts[2][1:-1].split(","):
                    listDictForIndegree[int(parts[0])//20][j] = listDictForIndegree[int(parts[0])//20].get(j, 0) + 1

    # Table that contains the in-degree for each node, for each cycle.
    in_degree_table = []
    for i in listDictForIndegree:
        in_degrees = []
        for j in i:
            in_degrees.append(int(i[j]))
        in_degree_table.append(in_degrees)

    # Box-plots
    fig = plt.figure()
    plt.title(f"In-degree of all the nodes for the {policy} policy")
    plt.xlabel("Cycle")
    plt.ylabel("In-degree")
    plt.boxplot(in_degree_table)
    plt.xticks(xaxis, cycles)
    plt.savefig(f"../graphs/{policy}.png")
    plt.savefig(f"../graphs/{policy}.pdf")
    plt.close()
