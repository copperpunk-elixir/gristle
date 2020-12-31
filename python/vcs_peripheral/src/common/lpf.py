class Lpf:
    def __init__(self, alpha):
        self.alpha = alpha
        self.value = None
    
    def add_value(self, value):
        self.value = self.value*self.alpha + value*(1.0-self.alpha)
    
    def add_value_with_alpha(self, value, alpha):
        if self.value is None:
            self.value = value
        else:
            self.value = self.value*alpha + value*(1.0-alpha)
