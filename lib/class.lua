local Assert = require("lib.assert")

local function createIndexWrapper(class, func)
  if func == nil then
    return class.__instance_dict
  elseif type(func) == "function" then
    return function(self, name)
      local value = class.__instance_dict[name]
      if value ~= nil then
        return value
      else
        return func(self, name)
      end
    end
  else
    return function(_, name)
      local value = class.__instance_dict[name]

      if value ~= nil then
        return value
      else
        return func[name]
      end
    end
  end
end

local function propagateInstanceMethod(class, name, func)
  if name == "__index" then
    func = createIndexWrapper(class, func)
  end

  class.__instance_dict[name] = func
  for subclass in pairs(class.subclasses) do
    if rawget(subclass.__declared_methods, name) == nil then
      propagateInstanceMethod(subclass, name, func)
    end
  end
end

local function declareInstanceMethod(class, name, func)
  class.__declared_methods[name] = func

  if func == nil and class.super then
    func = class.super.__instance_dict[name]
  end

  propagateInstanceMethod(class, name, func)
end

local function _toString(self) return "[class " .. self.name .. "]" end
local function _call(self, ...) return self:new(...) end

local function createClass(name, super)
  local dict = {}
  dict.__index = dict

  local class = {
    name = name,
    super = super,
    static = {},
    __instance_dict = dict,
    __declared_methods = {},
    subclasses = setmetatable({}, { __mode = 'k' })
  }

  if super then
    setmetatable(class.static, {
      __index = function(_, key)
        local result = rawget(dict, key)
        if result ~= nil then
          return result
        end

        return super.static[key]
      end
    })
  else
    setmetatable(class.static, {
      __index = function(_, key)
        return rawget(dict, key)
      end
    })
  end

  setmetatable(class, {
    __index = class.static,
    __tostring = _toString,
    __call = _call,
    __newindex = declareInstanceMethod
  })

  return class
end

local function includeMixin(class, mixin)
  Assert.assertIs(class, "table", "Mixin target must be a table")
  Assert.assertIs(mixin, "table", "Mixin must be a table")

  for name, method in pairs(mixin) do
    if name ~= "included" and name ~= "static" then
      class[name] = method
    end
  end

  for name, method in pairs(mixin.static or {}) do
    class.static[name] = method
  end

  if type(mixin.included) == "function" then
    mixin:included(class)
  end

  return class
end

local Default = {
  __tostring = function(self) return "[instance " .. self.class.name .. "]" end,
  init = function(self, ...) end,

  isInstanceOf = function(self, class)
    return type(class) == "table" and type(self) == "table" and
        (self.class == class or type(self.class) == "table" and
          type(self.class.isSubclassOf) == "function" and self.class:isSubclassOf(class))
  end,

  static = {
    allocate = function(self)
      Assert.assertIs(self, "table", "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
      return setmetatable({ class = self }, self.__instance_dict)
    end,

    new = function(self, ...)
      Assert.assertIs(self, "table", "Make sure that you are using 'Class:new' instead of 'Class.new'")
      local instance = self:allocate()
      instance:init(...)
      return instance
    end,

    subclass = function(self, name)
      Assert.assertIs(self, "table", "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
      Assert.assertIs(name, "string", "You must provide a name (as a string) for your class")

      local subclass = createClass(name, self)

      for methodName, func in pairs(self.__instance_dict) do
        if not (methodName == "__index" and type(func) == "table") then
          propagateInstanceMethod(subclass, methodName, func)
        end
      end

      subclass.init = function(instance, ...)
        return self.init(instance, ...)
      end

      self.subclasses[subclass] = true
      self:subclassed(subclass)

      return subclass
    end,

    subclassed = function(self, other) end,

    isSubclassOf = function(self, other)
      return type(other) == "table" and type(self.super) == "table" and
          (self.super == other or self.super:isSubclassOf(other))
    end,

    isInstance = function(self, other)
      return type(other) == "table" and type(other.isInstanceOf) == "function" and other:isInstanceOf(self)
    end,

    include = function(self, ...)
      Assert.assertIs(self, "table", "Make sure that you are using 'Class:include' instead of 'Class.include'")

      for _, mixin in ipairs({ ... }) do
        includeMixin(self, mixin)
      end

      return self
    end
  }
}

local Class = {}

function Class.class(name, super)
  Assert.assertIs(name, "string")
  if super then
    return super:subclass(name)
  end

  return includeMixin(createClass(name), Default)
end

setmetatable(Class, {
  __call = function(_, ...)
    return Class.class(...)
  end
})

return Class
