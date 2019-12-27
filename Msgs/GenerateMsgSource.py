import traceback
import sys
import os
import json
from collections import OrderedDict

# -----------------------------------------------------------------------------------------------------------

type_default_values = {
    "Byte"   : "0",
    "Word"   : "0",
    "String" : "''",
}

# -----------------------------------------------------------------------------------------------------------

type_size_values = {
    "Byte"   : lambda n: "1 +",
    "Word"   : lambda n: "2 +",
    "String" : lambda n: "4 + Length(F%s) +" % n,
}

# -----------------------------------------------------------------------------------------------------------

serializers = {
    "Byte"   : lambda n: "  Buf^ := F%s;\r\n" \
                         "  Inc(Buf);\r\n" % n,
    "Word"   : lambda n: "  Len := 2;\r\n" \
                         "  CopyMemory(Buf, @F%s, Len);\r\n" \
                         "  Inc(Buf, Len);\r\n" % n,
    "String" : lambda n: "  Len := Length(F%s);\r\n" \
                         "  CopyMemory(Buf, @Len, 4);\r\n" \
                         "  Inc(Buf, 4);\r\n" \
                         "  CopyMemory(Buf, @F%s[1], Len);\r\n" \
                         "  Inc(Buf, Len);\r\n" % (n, n),
}

# -----------------------------------------------------------------------------------------------------------

deserializers = {
    "Byte"   : lambda n: "  F%s := Buf^;\r\n" \
                         "  Inc(Buf);\r\n" % n,
    "Word"   : lambda n: "  Len := 2;\r\n" \
                         "  CopyMemory(@F%s, Buf, Len);\r\n" \
                         "  Inc(Buf, Len);\r\n" % n,
    "String" : lambda n: "  CopyMemory(@Len, Buf, 4);\r\n" \
                         "  SetLength(F%s, Len);\r\n" \
                         "  Inc(Buf, 4);\r\n" \
                         "  CopyMemory(@F%s[1], Buf, Len);\r\n" \
                         "  Inc(Buf, Len);\r\n" % (n, n),
}

# -----------------------------------------------------------------------------------------------------------

def add_fields(pas_file, fields):
    for name, type in fields.items():
        pas_file.write("      F%s : %s;\r\n" % (name, type))
    return

# -----------------------------------------------------------------------------------------------------------

def add_getter_declarations(pas_file, fields):
    for name, type in fields.items():
        pas_file.write("      function  Get%s : %s;\r\n" % (name, type))
    return

# -----------------------------------------------------------------------------------------------------------

def add_setter_declarations(pas_file, fields):
    for name, type in fields.items():
        pas_file.write("      procedure Set%s(AValue : %s);\r\n" % (name, type))
    return

# -----------------------------------------------------------------------------------------------------------

def add_properties(pas_file, fields):
    pas_file.write("      property Size : Cardinal read GetSize;\r\n")
    for name, type in fields.items():
        pas_file.write("      property %s : %s read Get%s write Set%s;\r\n" % (name, type, name, name))
    return

# -----------------------------------------------------------------------------------------------------------
    
def add_constructor(pas_file, msg, fields):
    pas_file.write("constructor T%s.Create();\r\n" % msg)
    pas_file.write("begin\r\n")
    pas_file.write("  inherited Create();\r\n")
    for name, type in fields.items():
        pas_file.write("  F%s := %s;\r\n" % (name, type_default_values.get(type)))
    pas_file.write("end;\r\n")
    pas_file.write("\r\n")
    return

# -----------------------------------------------------------------------------------------------------------

def add_implementation(pas_file, msg, fields):
    for name, type in fields.items():
        pas_file.write("function T%s.Get%s : %s;\r\n" % (msg, name, type))
        pas_file.write("begin\r\n")
        pas_file.write("  Result := F%s;\r\n" % name)
        pas_file.write("end;\r\n")
        pas_file.write("\r\n")
        
        pas_file.write("procedure T%s.Set%s(AValue : %s);\r\n" % (msg, name, type))
        pas_file.write("begin\r\n")
        pas_file.write("  F%s := AValue;\r\n" % name)
        pas_file.write("end;\r\n")
        pas_file.write("\r\n")
    return

# -----------------------------------------------------------------------------------------------------------

def add_size(pas_file, msg, fields):
    pas_file.write("function T%s.GetSize : Cardinal;\r\n" % msg)
    pas_file.write("begin\r\n")
    pas_file.write("  Result := \r\n")
    for name, type in fields.items():
        pas_file.write("    %s\r\n" % type_size_values.get(type)(name))
    pas_file.write("    0;\r\n")
    pas_file.write("end;\r\n")
    pas_file.write("\r\n")
    return

# -----------------------------------------------------------------------------------------------------------

def add_serializer(pas_file, msg, fields):
    pas_file.write("function T%s.Serialize(ABuffer : PByte) : Cardinal;\r\n" % msg)
    pas_file.write("var\r\n")
    pas_file.write("  Buf : PByte;\r\n")
    pas_file.write("  Len : Cardinal;\r\n")
    pas_file.write("begin\r\n")
    pas_file.write("  Buf := ABuffer;\r\n")
    pas_file.write("\r\n")
    
    for name, type in fields.items():
        pas_file.write("%s\r\n" % serializers.get(type)(name))
    
    pas_file.write("end;\r\n")
    pas_file.write("\r\n")
    return

# -----------------------------------------------------------------------------------------------------------

def add_deserializer(pas_file, msg, fields):
    pas_file.write("function T%s.Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;\r\n" % msg)
    pas_file.write("var\r\n")
    pas_file.write("  Buf : PByte;\r\n")
    pas_file.write("  Len : Cardinal;\r\n")
    pas_file.write("begin\r\n")
    pas_file.write("  Buf := ABuffer;\r\n")
    pas_file.write("\r\n")
    
    for name, type in fields.items():
        pas_file.write("%s\r\n" % deserializers.get(type)(name))
    
    pas_file.write("end;\r\n")
    pas_file.write("\r\n")
    return

# -----------------------------------------------------------------------------------------------------------

def generate(folder, msg, fields):
    print(" - Generating - %s" % msg)
    
    pas_file_name = os.path.join(folder, (msg + ".pas"))
    print(pas_file_name)
    pas_file = open(pas_file_name, 'w+b')

    pas_file.write("unit %s;\r\n" % msg)
    pas_file.write("\r\n")
    pas_file.write("interface\r\n")
    pas_file.write("\r\n")
    pas_file.write("uses")
    pas_file.write("  Windows, Classes, SysUtils, DateUtils;\r\n")
    pas_file.write("\r\n")
    pas_file.write("type\r\n")
    pas_file.write("  T%s = class(TPersistent)\r\n" % msg)
    pas_file.write("    private\r\n")
    add_fields(pas_file, fields)
    pas_file.write("\r\n")
    add_getter_declarations(pas_file, fields)
    pas_file.write("\r\n")
    add_setter_declarations(pas_file, fields)
    pas_file.write("    public\r\n")
    pas_file.write("      constructor Create();\r\n")
    pas_file.write("      function Serialize(ABuffer : PByte) : Cardinal;\r\n")
    pas_file.write("      function Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;\r\n")
    pas_file.write("      function GetSize : Cardinal;\r\n")
    pas_file.write("    published\r\n")
    add_properties(pas_file, fields)
    pas_file.write("    end;\r\n")
    pas_file.write("\r\n")
    pas_file.write("implementation\r\n")
    pas_file.write("\r\n")
    pas_file.write("{ T%s }\r\n" % msg)
    pas_file.write("\r\n")
    add_constructor(pas_file, msg, fields)
    add_size(pas_file, msg, fields)
    add_serializer(pas_file, msg, fields)
    add_deserializer(pas_file, msg, fields)
    add_implementation(pas_file, msg, fields)
    pas_file.write("end.\r\n")
    
    pas_file.close()
    
    return

# -----------------------------------------------------------------------------------------------------------

def main(argv = None):
    json_data = None

    if argv is None:
        argv = sys.argv
    
    print("ROS Message Delphi Generator 1.0")
    
    if (3 != len(sys.argv)):
        print("Usage: generator.py <in json> <out folder>")
        
    json_file_name = argv[1]
    pas_folder = argv[2]
    
    print('Input file    : %s' % json_file_name)
    print('Output folder : %s' % pas_folder)
    
    with open(json_file_name, "r") as json_file:
        json_data = json.load(json_file, object_pairs_hook=OrderedDict)
            
    for msg, fields in json_data.items():
        generate(pas_folder, msg, fields)

    return 0

# -----------------------------------------------------------------------------------------------------------

if __name__ == '__main__':
    sys.exit(main(sys.argv))