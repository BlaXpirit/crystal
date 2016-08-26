require "../../spec_helper"

describe "Code gen: macro" do
  it "expands macro" do
    assert run("macro foo; 1 + 2; end; foo").to_i == 3
  end

  it "expands macro with arguments" do
    assert run(%(
      macro foo(n)
        {{n}} + 2
      end

      foo(1)
      )).to_i == 3
  end

  it "expands macro that invokes another macro" do
    assert run(%(
      macro foo
        def x
          1 + 2
        end
      end

      macro bar
        foo
      end

      bar
      x
      )).to_i == 3
  end

  it "expands macro defined in class" do
    assert run(%(
      class Foo
        macro foo
          def bar
            1
          end
        end

        foo
      end

      foo = Foo.new
      foo.bar
    )).to_i == 1
  end

  it "expands macro defined in base class" do
    assert run(%(
      class Object
        macro foo
          def bar
            1
          end
        end
      end

      class Foo
        foo
      end

      foo = Foo.new
      foo.bar
    )).to_i == 1
  end

  it "expands inline macro" do
    assert run(%(
      a = {{ 1 }}
      a
      )).to_i == 1
  end

  it "expands inline macro for" do
    assert run(%(
      a = 0
      {% for i in [1, 2, 3] %}
        a += {{i}}
      {% end %}
      a
      )).to_i == 6
  end

  it "expands inline macro if (true)" do
    assert run(%(
      a = 0
      {% if 1 == 1 %}
        a += 1
      {% end %}
      a
      )).to_i == 1
  end

  it "expands inline macro if (false)" do
    assert run(%(
      a = 0
      {% if 1 == 2 %}
        a += 1
      {% end %}
      a
      )).to_i == 0
  end

  it "finds macro in class" do
    assert run(%(
      class Foo
        macro foo
          1 + 2
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      )).to_i == 3
  end

  it "expands def macro" do
    assert run(%(
      def bar_baz
        1
      end

      def foo : Int32
        {% begin %}
          bar_{{ "baz".id }}
        {% end %}
      end

      foo
      )).to_i == 1
  end

  it "expands def macro with var" do
    assert run(%(
      macro def foo : Int32
        a = {{ 1 }}
      end

      foo
      )).to_i == 1
  end

  it "expands def macro with @type.instance_vars" do
    assert run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def to_s : String
          {{ @type.instance_vars.first.stringify }}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string == "x"
  end

  it "expands def macro with @type.instance_vars with subclass" do
    assert run(%(
      class Reference
        def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
        def initialize(@x : Int32, @y : Int32)
        end
      end

      Bar.new(1, 2).to_s
      )).to_string == "y"
  end

  it "expands def macro with @type.instance_vars with virtual" do
    assert run(%(
      class Reference
        def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
        def initialize(@x : Int32, @y : Int32)
        end
      end

      (Bar.new(1, 2) || Foo.new(1)).to_s
      )).to_string == "y"
  end

  it "expands def macro with @type.name" do
    assert run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def to_s : String
          {{@type.name.stringify}}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string == "Foo"
  end

  it "expands macro and resolves type correctly" do
    assert run(%(
      class Foo
        macro def foo : Int32
          1
        end
      end

      class Bar < Foo
        Int32 = 2
      end

      Bar.new.foo
      )).to_i == 1
  end

  it "expands def macro with @type.name with virtual" do
    assert run(%(
      class Reference
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Bar.new || Foo.new).to_s
      )).to_string == "Bar"
  end

  it "expands def macro with @type.name with virtual (2)" do
    assert run(%(
      class Reference
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).to_s
      )).to_string == "Foo"
  end

  it "allows overriding macro definition when redefining base class" do
    assert run(%(
      class Foo
        def inspect : String
          {{@type.name.stringify}}
        end
      end

      class Bar < Foo
      end

      class Foo
        def inspect
          "OH NO"
        end
      end

      Bar.new.inspect
      )).to_string == "OH NO"
  end

  it "uses invocation context" do
    assert run(%(
      macro foo
        def bar
          {{@type.name.stringify}}
        end
      end

      class Foo
        foo
      end

      Foo.new.bar
      )).to_string == "Foo"
  end

  it "allows macro with default arguments" do
    assert run(%(
      def bar
        2
      end

      macro foo(x, y = :bar)
        {{x}} + {{y.id}}
      end

      foo(1)
      )).to_i == 3
  end

  it "expands def macro with instance var and method call (bug)" do
    assert run(%(
      struct Nil
        def to_i
          0
        end
      end

      class Foo
        @name : Int32?

        macro def foo : Int32
          name = 1
          @name = name
        end
      end

      Foo.new.foo.to_i
      )).to_i == 1
  end

  it "expands @type.name in virtual metaclass (1)" do
    assert run(%(
      class Class
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)
      p.value = Bar
      p.value = Foo
      p.value.to_s
      )).to_string == "Foo"
  end

  it "expands @type.name in virtual metaclass (2)" do
    assert run(%(
      class Class
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)
      p.value = Foo
      p.value = Bar
      p.value.to_s
      )).to_string == "Bar"
  end

  it "doesn't skip abstract classes when defining macro methods" do
    assert run(%(
      class Object
        macro def foo : Int32
          1
        end
      end

      class Type
      end

      class ModuleType < Type
        def foo
          2
        end
      end

      class Type1 < ModuleType
      end

      class Type2 < Type
      end

      t = Type1.new || Type2.new
      t.foo
      )).to_i == 2
  end

  it "doesn't reuse macro nodes (bug)" do
    assert run(%(
      def foo(x)
        {% for y in [1, 2] %}
          x + 1
        {% end %}
      end

      foo 1
      foo(1.5).to_i
      )).to_i == 2
  end

  it "can use constants" do
    assert run(%(
      A = 1
      {{ A }}
      )).to_i == 1
  end

  it "can refer to types" do
    assert run(%(
      class Foo
        def initialize(@x : Int32, @y : Int32)
        end

        macro def foo : String
          {{ Foo.instance_vars.last.name.stringify }}
        end

      end

      Foo.new(1, 2).foo
      )).to_string == "y"
  end

  it "runs macro with splat" do
    assert run(%(
      macro foo(*args)
        {{args.size}}
      end

      foo 1, 1, 1
      )).to_i == 3
  end

  it "runs macro with arg and splat" do
    assert run(%(
      macro foo(name, *args)
        {{args.size}}
      end

      foo bar, 1, 1, 1
      )).to_i == 3
  end

  it "expands macro that yields" do
    assert run(%(
      def foo
        {% for i in 0 .. 2 %}
          yield {{i}}
        {% end %}
      end

      a = 0
      foo do |x|
        a += x
      end
      a
      )).to_i == 3
  end

  it "can refer to abstract (1)" do
    assert run(%(
      class Foo
      end

      {{ Foo.abstract? }}
      )).to_b == false
  end

  it "can refer to abstract (2)" do
    assert run(%(
      abstract class Foo
      end

      {{ Foo.abstract? }}
      )).to_b == true
  end

  it "can refer to @type" do
    assert run(%(
      class Foo
        def foo : String
          {{@type.name.stringify}}
        end
      end

      Foo.new.foo
      )).to_string == "Foo"
  end

  it "can refer to union (1)" do
    assert run(%(
      {{Int32.union?}}
    )).to_b == false
  end

  it "can refer to union (2)" do
    assert run(%(
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union? }}
        end
      end
      Foo.new.foo
    )).to_b == true
  end

  it "can iterate union types" do
    assert run(%(
      require "prelude"
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union_types.map(&.name).sort }}.join("-")
        end
      end
      Foo.new.foo
    )).to_string == "Float64-Int32"
  end

  it "can access type variables" do
    assert run(%(
      class Foo(T)
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      Foo(Int32).new.foo
    )).to_string == "Int32"
  end

  it "can acccess type variables that are not types" do
    assert run(%(
      class Foo(T)
        def foo
          {{ @type.type_vars.first.is_a?(NumberLiteral) }}
        end
      end
      Foo(1).new.foo
    )).to_b == true
  end

  it "can acccess type variables of a tuple" do
    assert run(%(
      struct Tuple
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      {1, 2, 3}.foo
    )).to_string == "Int32"
  end

  it "can access type variables of a generic type" do
    assert run(%(
      require "prelude"
      class Foo(T, K)
        def self.foo : String
          {{ @type.type_vars.map(&.stringify) }}.join("-")
        end
      end
      Foo.foo
    )).to_string == "T-K"
  end

  it "receives &block" do
    assert run(%(
      macro foo(&block)
        bar {{block}}
      end

      def bar
        yield 1
      end

      foo do |x|
        x + 1
      end
      )).to_i == 2
  end

  it "executes with named arguments" do
    assert run(%(
      macro foo(x = 1)
        {{x}} + 1
      end

      foo x: 2
      )).to_i == 3
  end

  it "gets correct class name when there are classes in the middle" do
    assert run(%(
      class Foo
        def class_desc : String
          {{@type.name.stringify}}
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      class Qux < Bar
      end

      a = Pointer(Foo).malloc(1_u64)
      a.value = Qux.new
      a.value.class_desc
      )).to_string == "Qux"
  end

  it "transforms hooks (bug)" do
    codegen(%(
      module GC
        def self.add_finalizer(object : T)
          object.responds_to?(:finalize)
        end
      end

      abstract class Foo
        ALL = Pointer(Foo).malloc(1_u64)

        macro inherited
          ALL.value = new
        end
      end

      class Bar < Foo
      end
      ))
  end

  it "executs subclasses" do
    assert run(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      class Qux < Baz
      end

      names = {{ Foo.subclasses.map &.name }}
      names.join("-")
      )).to_string == "Bar-Baz"
  end

  it "executs all_subclasses" do
    assert run(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      names = {{ Foo.all_subclasses.map &.name }}
      names.join("-")
      )).to_string == "Bar-Baz"
  end

  it "gets enum members with @type.constants" do
    assert run(%(
      enum Color
        Red
        Green
        Blue

        def self.red
          {{@type.constants[0]}}
        end

        def self.green
          {{@type.constants[1]}}
        end

        def self.blue
          {{@type.constants[2]}}
        end
      end

      Color.red.value + Color.green.value + Color.blue.value
      )).to_i == 0 + 1 + 2
  end

  it "gets enum members as constants" do
    assert run(%(
      enum Color
        Red
        Green
        Blue
      end

      {{Color.constants[1].stringify}}
      )).to_string == "Green"
  end

  it "says that enum has Flags attribute" do
    assert run(%(
      @[Flags]
      enum Color
        Red
        Green
        Blue
      end

      {{Color.has_attribute?("Flags")}}
      )).to_b == true
  end

  it "says that enum doesn't have Flags attribute" do
    assert run(%(
      enum Color
        Red
        Green
        Blue
      end

      {{Color.has_attribute?("Flags")}}
      )).to_b == false
  end

  it "gets methods" do
    assert run(%(
      class Foo
        def bar
          1
        end

        def first_method_name : String
          {{ @type.methods.map(&.name.stringify).first }}
        end
      end

      Foo.new.first_method_name
      )).to_string == "bar"
  end

  it "copies base macro def to sub-subtype even after it was copied to a subtype (#448)" do
    assert run(%(
      class Object
        def class_name : String
          {{@type.name.stringify}}
        end
      end

      class A
        @@children : Pointer(A)
        @@children = Pointer(A).malloc(1_u64)

        def self.children
          @@children
        end
      end

      A.children.value = A.new
      A.children.value.class_name

      class B < A; end

      A.children.value = B.new
      A.children.value.class_name

      class C < B; end
      A.children.value = C.new
      A.children.value.class_name
      )).to_string == "C"
  end

  it "recalculates method when virtual metaclass type is added" do
    assert run(%(
      require "prelude"

      class Global
        @@x = [] of String
        @@runnables = [] of Runnable.class

        def self.x=(@@x)
        end

        def self.x
          @@x
        end

        def self.runnables
          @@runnables
        end
      end

      def run
        Global.runnables.each &.run
      end

      class Runnable
      end

      class Runnable
        macro inherited
          Global.runnables << self
        end

        def self.run : Nil
          Global.x << {{@type.name.stringify}}
          nil
        end
      end

      class Test < Runnable
      end

      run
      Global.x.clear

      class RunnableTest < Test
      end

      run
      Global.x.join(", ")
      )).to_string == "Test, RunnableTest"
  end

  it "correctly recomputes call (bug)" do
    assert run(%(
      class Object
        def in_object
          in_class(1)
        end
      end

      class Class
        def in_class(x)
          bar
        end

        def bar : String
          {{@type.name.stringify}}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      f = Bar.new || Foo.new
      f.class.in_object

      class Baz < Foo
      end

      f2 = Baz.new || Foo.new
      f2.class.in_object
      )).to_string == "Baz"
  end

  it "doesn't override local variable when using macro variable" do
    assert run(%(
      macro foo(x)
        %a = {{x}}
        %a
      end

      a = 1
      foo(2)
      foo(3)
      a
      )).to_i == 1
  end

  it "doesn't override local variable when using macro variable (2)" do
    assert run(%(
      macro foo(x)
        %a = {{x}} + 10
        %a
      end

      a = 1
      z = foo(2)
      w = foo(3)
      a + z + w
      )).to_i == 26
  end

  it "uses indexed macro variable" do
    assert run(%(
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total += %var{i}
        {% end %}
        %total
      end

      z = 0
      z += foo 4, 5, 6
      z += foo 40, 50, 60
      z
      )).to_i == 4 + 5 + 6 + 40 + 50 + 60
  end

  it "uses indexed macro variable with many keys" do
    assert run(%(
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{elem, i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total += %var{elem, i}
        {% end %}
        %total
      end

      z = foo 4, 5, 6
      z
      )).to_i == 4 + 5 + 6
  end

  it "codegens macro def with splat (#496)" do
    assert run(%(
      class Foo
        macro def bar(*args) : Int32
          args[0] + args[1] + args[2]
        end
      end

      Foo.new.bar(1, 2, 3)
      )).to_i == 6
  end

  it "codegens macro def with default arg (similar to #496)" do
    assert run(%(
      class Foo
        macro def bar(foo = 1) : Int32
          foo + 2
        end
      end

      Foo.new.bar
      )).to_i == 3
  end

  it "expands macro with default arg and splat (#784)" do
    assert run(%(
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro
      )).to_string == "5"
  end

  it "expands macro with default arg and splat (2) (#784)" do
    assert run(%(
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro 1, 2, 3, 4
      )).to_string == "1"
  end

  it "expands macro with default arg and splat (3) (#784)" do
    assert run(%(
      macro some_macro(a=5, *args)
        {{args.size}}
      end

      some_macro 1, 2, 3, 4
      )).to_i == 3
  end

  it "checks if macro expansion returns (#821)" do
    assert run(%(
      macro pass
        return 123
      end

      def me
        pass
        nil
      end

      me || 0
      ), inject_primitives: false).to_i == 123
  end

  it "passes #826" do
    assert run(%(
      macro foo
        macro bar
          {{yield}}
        end
      end

      foo do
        123
      end

      bar
      )).to_i == 123
  end

  it "declares constant in macro (#838)" do
    assert run(%(
      macro foo
        {{yield}}
      end

      foo do
        X = 123
      end

      X
      )).to_i == 123
  end

  it "errors if dynamic constant assignment after macro expansion" do
    assert_error %(
      macro foo
        X = 123
      end

      def bar
        foo
      end

      bar
      ),
      "dynamic constant assignment"
  end

  it "finds macro from virtual type" do
    assert run(%(
      class Foo
        macro foo
          123
        end

        def bar
          foo
        end
      end

      class Bar < Foo
      end

      a = Pointer(Foo).malloc(1_u64)
      a.value = Foo.new
      a.value.bar
      )).to_i == 123
  end

  it "expands macro with escaped quotes (#895)" do
    assert run(%(
      macro foo(x)
        "{{x}}\\""
      end

      foo hello
      )).to_string == %(hello")
  end

  it "expands macro def with return (#1040)" do
    assert run(%(
      macro def a : Int32
        return 123
      end

      a
      )).to_i == 123
  end

  it "fixes empty types of macro expansions (#1379)" do
    assert run(%(
      macro lala(exp)
        {{exp}}
      end

      def foo
        bar do
          return 123
        end
      end

      def bar
        return yield
      end

      lala foo
      )).to_i == 123
  end

  it "expands macro as class method" do
    assert run(%(
      class Foo
        macro bar
          1
        end
      end

      Foo.bar
      )).to_i == 1
  end

  it "expands macro as class method and accesses @type" do
    assert run(%(
      class Foo
        macro bar
          {{@type.stringify}}
        end
      end

      Foo.bar
      )).to_string == "Foo"
  end

  it "codegens macro with comment (bug) (#1396)" do
    assert run(%(
      macro my_macro
        # {{ 1 }}
        {{ 1 }}
      end

      my_macro
      )).to_i == 1
  end

  it "correctly resolves constant inside block in macro def" do
    assert run(%(
      def foo
        yield
      end

      class Foo
        Const = 123

        macro def self.bar : Int32
          foo { Const }
        end
      end

      Foo.bar
      )).to_i == 123
  end

  it "can access free variables" do
    assert run(%(
      def foo(x : T)
        {{ T.stringify }}
      end

      foo(1)
      )).to_string == "Int32"
  end

  it "types macro expansion bug (#1734)" do
    assert run(%(
      class Foo
        macro def foo : Int32
          1 || 2
        end
      end

      class Bar < Foo
      end

      x = true ? Foo.new : Bar.new
      x.foo
      )).to_i == 1
  end

  it "expands Path with resolve method" do
    assert run(%(
      A = 1

      macro id(path)
        {{path.resolve}}
      end

      id(A)
      )).to_i == 1
  end

  it "solves macro expression arguments before macro expansion (type)" do
    assert run(%(
      macro name(x)
        {{x.name.stringify}}
      end

      name({{String}})
      )).to_string == "String"
  end

  it "solves macro expression arguments before macro expansion (constant)" do
    assert run(%(
      CONST = 1

      macro id(x)
        {{x}}
      end

      id({{CONST}})
      )).to_i == 1
  end

  it "can use macro inside array literal" do
    assert run(%(
      require "prelude"

      macro foo
        42
      end

      ary = [foo]
      ary[0]
      )).to_i == 42
  end

  it "can use macro inside hash literal" do
    assert run(%(
      require "prelude"

      macro foo
        42
      end

      hash = {foo => foo}
      hash[foo]
      )).to_i == 42
  end

  it "executes with named arguments for positional arg (1)" do
    assert run(%(
      macro foo(x)
        {{x}} + 1
      end

      foo x: 2
      )).to_i == 3
  end

  it "executes with named arguments for positional arg (2)" do
    assert run(%(
      macro foo(x, y)
        {{x}} + {{y}} + 1
      end

      foo x: 2, y: 3
      )).to_i == 6
  end

  it "executes with named arguments for positional arg (3)" do
    assert run(%(
      class String
        def bytesize
          @bytesize
        end
      end

      macro foo(x, y)
        {{x}} + {{y}}.bytesize + 1
      end

      foo y: "foo", x: 2
      )).to_i == 6
  end

  it "stringifies type without virtual marker" do
    assert run(%(
      class Foo
        def foo_m : Int32
          {{ @type }}.foo
        end

        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      (Bar.new || Foo.new).foo_m
      )).to_i == 2
  end

  it "uses tuple T in method with free vars" do
    assert run(%(
      struct Tuple
        def foo(x : U)
          {{T.size}}
        end
      end

      {1, 3}.foo(1)
      )).to_i == 2
  end

  it "implicitly marks method as macro def when using @type" do
    assert run(%(
      class Foo
        def method
          {{@type.stringify}}
        end
      end

      class Bar < Foo
      end

      Bar.new.as(Foo).method
      )).to_string == "Bar"
  end

  it "doesn't replace %s in string (#2178)" do
    assert run(%(
      {% begin %}
        "hello %s"
      {% end %}
      )).to_string == "hello %s"
  end

  it "doesn't replace %q() (#2178)" do
    assert run(%(
      {% begin %}
        %q(hello)
      {% end %}
      )).to_string == "hello"
  end

  it "replaces %s inside string inside interpolation (#2178)" do
    assert run(%(
      require "prelude"

      {% begin %}
        %a = "world"
        "hello \#{ %a }"
      {% end %}
      )).to_string == "hello world"
  end

  it "replaces %s inside string inside interpolation, with braces (#2178)" do
    assert run(%(
      require "prelude"

      {% begin %}
        %a = "world"
        "hello \#{ [{ %a, %a }, %a] }"
      {% end %}
      )).to_string == %(hello [{"world", "world"}, "world"])
  end

  it "retains original yield expression (#2923)" do
    assert run(%(
      macro foo
        def bar(baz)
          {{yield}}
        end
      end

      foo do
        baz
      end

      bar("hi")
      )).to_string == "hi"
  end

  it "surrounds {{yield}} with begin/end" do
    assert run(%(
      macro foo
        a = {{yield}}
      end

      a = 0
      foo do
        1
        2
      end
      a
      )).to_i == 2
  end
end
