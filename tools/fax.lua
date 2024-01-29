local digitizer = peripheral.find("digitizer")
if not digitizer then
    digitizer = peripheral.find("digitizier")
    if not digitizer then
        printError("Failed to find digitizer peripheral")
        return
    end
end

local modem = peripheral.wrap("left")
if not modem then
    printError("Failed to find modem peripheral")
    return
end

local info = digitizer.getItemDetail(1)
if info == nil then
    print("No items to digitize")
    return
end

local result, err = digitizer.digitize()
if not result then
    printError("Failed to digitize: " + err)
    return
end

print(("Digitized %dx %s: %s"):format(result.count, result.item.name, result.item.id))

print("Sending to storage ...")
rednet.open("left")
rednet.broadcast({ result.item.id }, "bannet:storagebot.digitizer")
print("Done")
