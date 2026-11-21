noinline fn odd(n: usize) bool {
    if (n == 0) return false;
    return is_even_captured(n - 1);
}

// Exercise a legal helper name that shares the export's old certificate suffix.
noinline fn is_even_captured(n: usize) bool {
    if (n == 0) return true;
    return odd(n - 1);
}

export fn is_even(n: usize) bool {
    return is_even_captured(n);
}
