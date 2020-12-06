import matplotlib.pyplot as plt
import os

for file in os.listdir("./graphs"):
    matPlot = []
    listDictForIndegree = []
    with open("./graphs/"+file, "r") as f:
        print(file)
        lines = f.readlines()
        listDictForIndegree = [{} for i in range(9)]
        for i in lines:
            #format =  Cycle;NodeID;[NodeID1,NodeID2,....]
            parts = i.replace("\n", "").split(";")
            if int(parts[0])%20 == 0:
                for j in parts[2][1:-1].split(","):
                    listDictForIndegree[int(parts[0])//20 - 1][j] = listDictForIndegree[int(parts[0])//20 - 1].get(j, 0) + 1
    xss = []
    yss = []
    #xss matrice ou chaque ligne contient le nom des noeuds
    #yss matrice ou chaque ligne contient l'indegree des noeuds
    for i in listDictForIndegree:
        xs = []
        ys = []
        for j in i:
            xs.append(int(j))
            ys.append(int(i[j]))
        xss.append(xs)
        yss.append(ys)
    plt.boxplot(xss)
    plt.show()
