import matplotlib.pyplot as plt
import os

xaxis = [i for i in range(1, 11, 1)]
cycles = [i for i in range(0, 181, 20)]

for file in os.listdir("../results"):
    policy = file.split('.')[0]
    matPlot = []
    listDictForIndegree = []
    with open("../results/"+file, "r") as f:
        lines = f.readlines()
        listDictForIndegree = [{} for i in range(10)]
        for i in lines:
            #format =  Cycle;NodeID;[PeerID1,PeerID2,....]
            parts = i.strip().split(";")
            if int(parts[0])%20 == 0:
                for j in parts[2][1:-1].split(","):
                    listDictForIndegree[int(parts[0])//20][j] = listDictForIndegree[int(parts[0])//20].get(j, 0) + 1

    # Table that contains the in-degree for each node, for each cycle.
    xss = []
    for i in listDictForIndegree:
        xs = []
        for j in i:
            xs.append(int(j))
        xss.append(xs)

    print(xss)
    # Box-plots
    fig = plt.figure()
    plt.title(f"In-degree of all the nodes in the network for the {policy} policy")
    plt.xlabel("Cycle")
    plt.ylabel("In-degree")
    plt.boxplot(xss)
    plt.xticks(xaxis, cycles)
    plt.savefig(f"../graphs/{policy}.png")
    plt.savefig(f"../graphs/{policy}.pdf")
    plt.close()
