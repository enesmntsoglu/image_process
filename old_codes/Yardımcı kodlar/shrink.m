function val= shrink(x, a)
    val=sign(x).*max(abs(x)-a,0);
return;