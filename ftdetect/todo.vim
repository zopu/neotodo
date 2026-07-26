" Detect TODO.txt, todo.txt and TODO_<name>.txt / todo_<name>.txt files
autocmd BufRead,BufNewFile TODO.txt,todo.txt,TODO_*.txt,todo_*.txt setfiletype neotodo
