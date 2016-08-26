require "../../spec_helper"

describe "Codegen: class var" do
  it "codegens class var" do
    assert run("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i == 1
  end

  it "codegens class var as nil" do
    assert run("
      struct Nil; def to_i; 0; end; end

      class Foo
        @@foo = nil

        def self.foo
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i == 0
  end

  it "codegens class var inside instance method" do
    assert run("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ").to_i == 1
  end

  it "codegens class var as nil if assigned for the first time inside method" do
    assert run("
      struct Nil; def to_i; 0; end; end

      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i == 1
  end

  it "codegens class var inside module" do
    assert run("
      module Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i == 1
  end

  it "accesses class var from proc literal" do
    assert run("
      class Foo
        @@a = 1

        def self.foo
          ->{ @@a }.call
        end
      end

      Foo.foo
      ").to_i == 1
  end

  it "reads class var before initializing it (hoisting)" do
    assert run(%(
      x = Foo.var

      class Foo
        @@var = 42

        def self.var
          @@var
        end
      end

      x
      )).to_i == 42
  end

  it "uses var in class var initializer" do
    assert run(%(
      class Foo
        @@var : Int32
        @@var = begin
          a = class_method
          a + 3
        end

        def self.var
          @@var
        end

        def self.class_method
          1 + 2
        end
      end

      Foo.var
      )).to_i == 6
  end

  it "reads simple class var before another complex one" do
    assert run(%(
      class Foo
        @@var2 : Int32
        @@var2 = @@var + 1

        @@var = 41

        def self.var2
          @@var2
        end
      end

      Foo.var2
      )).to_i == 42
  end

  it "initializes class var of union with single type" do
    assert run(%(
      class Foo
        @@var : Int32 | String
        @@var = 42

        def self.var
          @@var
        end
      end

      var = Foo.var
      if var.is_a?(Int32)
        var
      else
        0
      end
      )).to_i == 42
  end

  it "initializes class var with array literal" do
    assert run(%(
      require "prelude"

      class Foo
        @@var = [1, 2, 4]

        def self.var
          @@var
        end
      end

      Foo.var.size
      )).to_i == 3
  end

  it "codegens second class var initializer" do
    assert run(%(
      class Foo
        @@var = 1
        @@var = 2

        def self.var
          @@var
        end
      end

      Foo.var
      )).to_i == 2
  end

  it "initializes dependent constant before class var" do
    assert run(%(
      def foo
        a = 1
        b = 2
        a + b
      end

      A = foo()

      class Foo
        @@foo : Int32
        @@foo = A

        def self.foo
          @@foo
        end
      end

      Foo.foo
      )).to_i == 3
  end

  it "declares and initializes" do
    assert run(%(
      class Foo
        @@x : Int32 = 42

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i == 42
  end

  it "doesn't use nilable type for initializer" do
    assert run(%(
      class Foo
        @@foo : Int32?
        @@foo = 42

        @@bar : Int32?
        @@bar = @@foo

        def self.bar
          @@bar
        end
      end

      Foo.bar || 10
      )).to_i == 42
  end

  it "codegens class var with begin and vars" do
    assert run("
      class Foo
        @@foo : Int32
        @@foo = begin
          a = 1
          b = 2
          a + b
        end

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i == 3
  end

  it "codegens class var with type declaration begin and vars" do
    assert run("
      class Foo
        @@foo : Int32 = begin
          a = 1
          b = 2
          a + b
        end

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i == 3
  end

  it "codegens class var with nilable reference type" do
    assert run(%(
      class Foo
        @@foo : String? = nil

        def self.foo
          @@foo ||= "hello"
        end
      end

      Foo.foo
      )).to_string == "hello"
  end

  it "initializes class var the moment it reaches it" do
    assert run(%(
      require "prelude"

      ENV["FOO"] = "BAR"

      class Foo
        @@x = ENV["FOO"]

        def self.x
          @@x
        end
      end

      w = Foo.x
      z = Foo.x
      z
      )).to_string == "BAR"
  end

  it "gets pointerof class var" do
    assert run(%(
      z = Foo.foo

      class Foo
        @@foo = 10

        def self.foo
          pointerof(@@foo).value
        end
      end

      z
      )).to_i == 10
  end

  it "gets pointerof class var complex constant" do
    assert run(%(
      z = Foo.foo

      class Foo
        @@foo : Int32
        @@foo = begin
          a = 10
          a
        end

        def self.foo
          pointerof(@@foo).value
        end
      end

      z
      )).to_i == 10
  end

  it "doesn't inherit class var value in subclass" do
    assert run(%(
      class Foo
        @@var = 1

        def self.var
          @@var
        end

        def self.var=(@@var)
        end
      end

      class Bar < Foo
      end

      Foo.var = 2

      Bar.var
      )).to_i == 1
  end

  it "doesn't inherit class var value in module" do
    assert run(%(
      module Moo
        @@var = 1

        def var
          @@var
        end

        def self.var=(@@var)
        end
      end

      class Foo
        include Moo
      end

      Moo.var = 2

      Foo.new.var
      )).to_i == 1
  end

  it "reads class var from virtual type" do
    assert run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end

        def var
          @@var
        end
      end

      class Bar < Foo
      end

      Bar.var = 2

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value.var
      )).to_i == 2
  end

  it "reads class var from virtual type metaclass" do
    assert run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end
      end

      class Bar < Foo
      end

      Bar.var = 2

      ptr = Pointer(Foo.class).malloc(1_u64)
      ptr.value = Bar
      ptr.value.var
      )).to_i == 2
  end

  it "writes class var from virtual type" do
    assert run(%(
      class Foo
        @@var = 1

        def self.var=(@@var)
        end

        def self.var
          @@var
        end

        def var=(@@var)
        end
      end

      class Bar < Foo
      end

      ptr = Pointer(Foo).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value.var = 2

      Bar.var
      )).to_i == 2
  end

  it "declares var as uninitialized and initializes it unsafely" do
    assert run(%(
      class Foo
        @@x = uninitialized Int32
        @@x = Foo.bar

        def self.bar
          if 1 == 2
            @@x
          else
            10
          end
        end

        def self.x
          @@x
        end
      end

      Foo.x
      )).to_i == 10
  end

  it "doesn't crash with pointerof from another module" do
    assert run(%(
      require "prelude"

      class Foo
        @@x : Int32?
        @@x = 1

        def self.x
          pointerof(@@x).value
        end
      end

      class Bar
        def self.bar
          Foo.x
        end
      end

      Bar.bar
      )).to_i == 1
  end
end
