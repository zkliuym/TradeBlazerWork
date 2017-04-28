file_object = open('simuser.txt', 'w+')
for i in range(5000):
    string = 'tbsim_2017_{:0>6}\n'.format(i)
    file_object.write("%s" %string)
file_object.close()