import src.comms.operator as operator

def speak():
    operator.open("dumb")
    msg = "Hello World"
    print(msg)
    return msg