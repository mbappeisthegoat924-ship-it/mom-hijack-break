def get_water_advice(glasses, break_num):
    goal=15
    left=goal - glasses
    if glasses >= goal:
        return("You have done good preserving your life!")
    else:
        if glasses < break_num*1.4:
            return("Drink 2 glasses of water this break to catch up!")
        else:
            return("Drink 1 glass of water to stay on track!")
print(get_water_advice(3,4))