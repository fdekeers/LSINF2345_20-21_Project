import matplotlib.pyplot as plt

matPlot = []
listDictForIndegree = []
with open("result.txt") as f:
    lines = f.readlines()
    listDictForIndegree = [{} for i in range(len(lines/20))]
    for i in lines:
        words = i.split(",").strip()
        for j in words[2:]:
            listDictForIndegree[int(words[0])//20 - 1][j] = listDictForIndegree[int(words[0])//20 - 1].get(j, 0) + 1


xss = []
yss = []
for i in listDictForIndegree:
    xs = []
    ys = []
    for j in i:
        xs.append(j)
        ys.append(i[j])
    xss.append(xs)
    yss.append(ys)

#xss matrice ou chaque ligne contient le nom des noeuds
#yss matrice ou chaque ligne contient l'indegree des noeuds




#format =  Cycle, NodeID, NodeID1, NodeID2, ...
