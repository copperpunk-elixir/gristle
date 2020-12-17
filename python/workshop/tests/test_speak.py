import src.utils.hello as hello
import src.comms.operator as op

def test_hello_world():
    op.open("this")
    assert hello.speak() == "Hello World"