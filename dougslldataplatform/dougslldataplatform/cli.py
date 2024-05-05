from rich.console import Console
from rich.table import Table
from typer import Argument, Context, Exit, Option, Typer

from dougslldataplatform import __version__
from dougslldataplatform.ingest import ingest as _ingest

console = Console()
app = Typer()


def version_func(flag):
    if flag:
        print(__version__)
        raise Exit(code=0)


@app.callback(invoke_without_command=True)
def main(
    ctx: Context,
    version: bool = Option(False, callback=version_func, is_flag=True),
):
    message = """Hello World Message"""
    if ctx.invoked_subcommand:
        return
    console.print(message)


@app.command()
def ingest():
    table = Table()
    value = _ingest()

    table.add_column(' JOB INGEST STATUS')
    table.add_row(value)

    console.print(table)


@app.command()
def hello():
    table = Table()
    table.add_column(' DATA MASTER - DOUGLAS LEAL')
    table.add_row(' CALTON HELLO WORLD')
    console.print(table)
