# FixML

FixML tool for providing personalized feedback to students.
It corrects the logical error for function programming assignments.
The tool is licensed under the [MIT license](LICENSE.txt).

## Basic Settings

Since the tool is implemented in OCaml, you have to install OCaml and packages:

```bash
sudo apt-get install ocaml
sudo apt-get install ocamlbuild
sudo apt-get install opam
```

The tool uses the libraries, ``core``, ``batteries``, ``menhir`` and ``aez``.
You can install the libraries using opam with follwing commands:

```bash
opam install core
opam install batteries
...
```

## Build

After installing the prerequisites, run the build script:

```bash
cd engine
eval `opam config env`
./build
```

If the compilation is done, you can check that the ``main.native`` is created.

## How to Run

To use the FixML, you need to input:

 - Student's program that has logical error
 - The function name of the problem
 - Correct implemetation
 - Testcases

Then, FixML will output the corrected version of the student's program.
The template for running the FixML as follows:

```bash
engine/main.native -submission [submissions path] -entry [function name] -solution [solution path] -testcases [testcases path]
```

For example, we can run a submission of problem filter with following command:

```bash
engine/main.native -submission benchmarks/filter/filter/submissions/sub1.ml -entry filter -solution benchmarks/filter/filter/sol.ml -testcases benchmarks/filter/filter/testcases
```

The correct implementation and student's program must be written with OCaml.
Especially, the format of testcases is restricted.
The format is ```{[input_11];[input_12];...;[input_1n]=>[output1];[input_21];[input_22];...;[input2n]=>[output2];...}```.
For instance, the testcases of proble filter is:
```
{
  (fun n-> n*(-1) <= 0);[-5;10;3] => [10;3];
  (fun n -> (n mod 2) = 0);[1;3;2;4] => [2;4];
  ...
}
```
