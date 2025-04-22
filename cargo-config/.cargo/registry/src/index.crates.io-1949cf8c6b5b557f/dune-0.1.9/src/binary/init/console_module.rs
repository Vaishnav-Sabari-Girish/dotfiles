use common_macros::b_tree_map;
use dune::{Environment, Error, Expression, Int};
use terminal_size::{terminal_size, Height, Width};

pub fn get() -> Expression {
    (b_tree_map! {
        String::from("width") => Expression::builtin("width", width, "get the width of the console"),
        String::from("height") => Expression::builtin("height", height, "get the height of the console"),
        String::from("write") => Expression::builtin("write", write, "write text to a specific position in the console"),
        String::from("title") => Expression::builtin("title", title, "set the title of the console"),
        String::from("clear") => Expression::builtin("clear", clear, "clear the console"),
    })
    .into()
}

fn width(_: Vec<Expression>, _: &mut Environment) -> Result<Expression, Error> {
    Ok(match terminal_size() {
        Some((Width(w), _)) => (w as Int).into(),
        _ => Expression::None,
    })
}

fn height(_: Vec<Expression>, _: &mut Environment) -> Result<Expression, Error> {
    Ok(match terminal_size() {
        Some((_, Height(h))) => (h as Int).into(),
        _ => Expression::None,
    })
}

fn write(args: Vec<Expression>, env: &mut Environment) -> Result<Expression, Error> {
    super::check_exact_args_len("write", &args, 3)?;
    match (args[0].eval(env)?, args[1].eval(env)?, args[2].eval(env)?) {
        (Expression::Integer(x), Expression::Integer(y), content) => {
            let content = content.to_string();
            for (y_offset, line) in content.lines().enumerate() {
                print!(
                    "\x1b[s\x1b[{row};{column}H\x1b[{row};{column}f{content}\x1b[u",
                    column = x,
                    row = y + y_offset as Int,
                    content = line
                );
            }
        }
        (x, y, _) => {
            return Err(Error::CustomError(format!(
                "expected first two arguments to be integers, but got: `{:?}`, `{:?}`",
                x, y
            )))
        }
    }
    Ok(Expression::None)
}

fn title(args: Vec<Expression>, env: &mut Environment) -> Result<Expression, Error> {
    super::check_exact_args_len("title", &args, 1)?;
    print!("\x1b]2;{}\x1b[0m", args[0].eval(env)?);
    Ok(Expression::None)
}

fn clear(args: Vec<Expression>, _env: &mut Environment) -> Result<Expression, Error> {
    super::check_exact_args_len("clear", &args, 1)?;
    print!("\x1b[2J\x1b[H");
    Ok(Expression::None)
}
