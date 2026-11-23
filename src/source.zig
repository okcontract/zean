// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Zig's tokenizer and AST are the source-admission frontend.
const std = @import("std");
const c = @import("common.zig");
pub const Token = struct { text: []const u8, start: usize, end: usize, tag: std.zig.Token.Tag };
pub const Parser = struct {
    ctx: *c.Context,
    tokens: []const Token,
    pos: usize = 0,
    pub fn peek(self: Parser) []const u8 {
        return if (self.pos < self.tokens.len) self.tokens[self.pos].text else "<eof>";
    }
    pub fn pop(self: *Parser) c.Error![]const u8 {
        if (self.pos >= self.tokens.len) return self.ctx.fail("unexpected end of source", .{});
        const value = self.tokens[self.pos].text;
        self.pos += 1;
        return value;
    }
    pub fn take(self: *Parser, value: []const u8) bool {
        if (!std.mem.eql(u8, self.peek(), value)) return false;
        self.pos += 1;
        return true;
    }
    pub fn expect(self: *Parser, text: []const u8) c.Error!void {
        const wanted = try tokenize(self.ctx, text);
        for (wanted) |token| {
            const actual = try self.pop();
            if (!std.mem.eql(u8, actual, token.text)) return self.ctx.fail("source admission expected {s}, found {s} at token {d}", .{ token.text, actual, self.pos });
        }
    }
    pub fn ident(self: *Parser) c.Error![]const u8 {
        const value = try self.pop();
        try self.ctx.require(plainIdentifier(value), "expected source identifier");
        return value;
    }
    pub fn integer(self: *Parser, comptime T: type) c.Error!T {
        const value = try self.pop();
        return std.fmt.parseInt(T, value, 0) catch return self.ctx.fail("unsupported source integer", .{});
    }
    pub fn done(self: Parser) c.Error!void {
        try self.ctx.require(self.pos == self.tokens.len, "unreviewed source suffix");
    }
};
pub fn plainIdentifier(value: []const u8) bool {
    if (value.len == 0 or (!std.ascii.isAlphabetic(value[0]) and value[0] != '_')) return false;
    for (value[1..]) |char| if (!std.ascii.isAlphanumeric(char) and char != '_') return false;
    return true;
}
pub fn tokenize(ctx: *c.Context, bytes: []const u8) c.Error![]const Token {
    try ctx.require(bytes.len <= 64 * 1024 * 1024, "source exceeds admission limit");
    const source = try ctx.allocator.dupeSentinel(u8, bytes, 0);
    var lexer = std.zig.Tokenizer.init(source);
    var result: std.ArrayList(Token) = .empty;
    while (true) {
        const token = lexer.next();
        switch (token.tag) {
            .eof => break,
            .invalid => return ctx.fail("unrecognized Zig source token at {d}", .{token.loc.start}),
            .doc_comment, .container_doc_comment => continue,
            else => {
                const spelling = source[token.loc.start..token.loc.end];
                // Preserve the token granularity of the reviewed source contracts
                // while letting Zig identify strings, comments and byte spans.
                if (c.oneOf(spelling, &.{ ">>=", "<<=" })) {
                    try result.append(ctx.allocator, .{ .text = spelling[0..1], .start = token.loc.start, .end = token.loc.start + 1, .tag = token.tag });
                    try result.append(ctx.allocator, .{ .text = spelling[1..], .start = token.loc.start + 1, .end = token.loc.end, .tag = token.tag });
                } else if (c.oneOf(spelling, &.{ ".*", "..", "...", "+%", "-%", "*%", "<<", ">>", "+=", "*=", "/=", "%=", "&=", "|=", "^=", "++", "+%=", "-%=", "*%=", "+|", "-|", "*|", "<<|", "+|=", "-|=", "*|=", "<<|=" })) {
                    for (0..spelling.len) |offset| try result.append(ctx.allocator, .{ .text = spelling[offset .. offset + 1], .start = token.loc.start + offset, .end = token.loc.start + offset + 1, .tag = token.tag });
                } else try result.append(ctx.allocator, .{ .text = spelling, .start = token.loc.start, .end = token.loc.end, .tag = token.tag });
            },
        }
    }
    return result.toOwnedSlice(ctx.allocator);
}
pub fn validateAst(ctx: *c.Context, bytes: []const u8) c.Error!void {
    const terminated = try ctx.allocator.dupeSentinel(u8, bytes, 0);
    var tree = std.zig.Ast.parse(ctx.allocator, terminated, .{ .mode = .zig }) catch return ctx.fail("Zig AST parse failed", .{});
    defer tree.deinit(ctx.allocator);
    try ctx.require(tree.errors.len == 0, "source is not valid Zig syntax");
}
/// Select names among an AST owner's direct members before checking their
/// tokens. A matching signature in another container cannot satisfy admission.
pub const Declarations = struct {
    ctx: *c.Context,
    tree: std.zig.Ast,

    pub fn init(ctx: *c.Context, bytes: []const u8) c.Error!Declarations {
        try ctx.require(bytes.len <= 64 * 1024 * 1024, "source exceeds admission limit");
        const terminated = try ctx.allocator.dupeSentinel(u8, bytes, 0);
        var tree = try std.zig.Ast.parse(ctx.allocator, terminated, .{ .mode = .zig });
        errdefer tree.deinit(ctx.allocator);
        try ctx.require(tree.errors.len == 0, "source is not valid Zig syntax");
        return .{ .ctx = ctx, .tree = tree };
    }
    pub fn deinit(self: *Declarations) void {
        self.tree.deinit(self.ctx.allocator);
    }
    pub fn root(self: *const Declarations) Scope {
        return .{ .source = self, .node = .root };
    }
};
pub const Scope = struct {
    source: *const Declarations,
    node: std.zig.Ast.Node.Index,
    parent: ?*const Scope = null,

    fn memberName(self: Scope, member: std.zig.Ast.Node.Index) c.Error!?[]const u8 {
        const tree = self.source.tree;
        var fn_buffer: [1]std.zig.Ast.Node.Index = undefined;
        const token = if (tree.fullVarDecl(member)) |decl| decl.ast.mut_token + 1 else if (tree.fullFnProto(&fn_buffer, member)) |decl| decl.name_token orelse return null else if (tree.fullContainerField(member)) |field| field.ast.main_token else return null;
        const spelling = tree.tokenSlice(token);
        // Decode quoted names too, so @"Id" cannot hide a duplicate Id.
        return if (std.mem.startsWith(u8, spelling, "@\"")) try importName(self.source.ctx, spelling[1..]) else spelling;
    }

    fn named(self: Scope, name: []const u8) c.Error!?std.zig.Ast.Node.Index {
        const tree = self.source.tree;
        var buffer: [2]std.zig.Ast.Node.Index = undefined;
        const owner = tree.fullContainerDecl(&buffer, self.node) orelse return self.source.ctx.fail("unsupported declaration owner", .{});
        var found: ?std.zig.Ast.Node.Index = null;
        for (owner.ast.members) |member| {
            const actual = try self.memberName(member) orelse continue;
            if (!std.mem.eql(u8, actual, name)) continue;
            try self.source.ctx.require(found == null, "ambiguous source declaration in owner");
            found = member;
        }
        return found;
    }
    fn selected(self: Scope, signature: []const u8) c.Error!std.zig.Ast.Node.Index {
        var pattern: Parser = .{ .ctx = self.source.ctx, .tokens = try tokenize(self.source.ctx, signature) };
        _ = pattern.take("pub");
        if (c.oneOf(pattern.peek(), &.{ "const", "var", "fn" })) _ = try pattern.pop();
        const name = try pattern.ident();
        return try self.named(name) orelse self.source.ctx.fail("missing source declaration in owner: {s}", .{name});
    }
    pub fn functionNode(self: Scope, name: []const u8) c.Error!std.zig.Ast.Node.Index {
        const node = try self.named(name) orelse return self.source.ctx.fail("missing function in source owner", .{});
        try self.source.ctx.require(self.source.tree.nodeTag(node) == .fn_decl, "source member is not a function definition");
        return node;
    }
    pub fn function(self: Scope, name: []const u8, buffer: *[1]std.zig.Ast.Node.Index) c.Error!std.zig.Ast.full.FnProto {
        const node = try self.functionNode(name);
        return self.source.tree.fullFnProto(buffer, node) orelse self.source.ctx.fail("unsupported function declaration", .{});
    }
    pub fn declaration(self: Scope, signature: []const u8) c.Error!Parser {
        const node = try self.selected(signature);
        const tree = self.source.tree;
        const first = tree.firstToken(node);
        var last = tree.lastToken(node);
        // AST declaration spans exclude their trailing semicolon or field comma.
        if (tree.fullVarDecl(node) != null) {
            try self.source.ctx.require(tree.tokenTag(last + 1) == .semicolon, "missing declaration terminator");
            last += 1;
        } else if (tree.fullContainerField(node) != null and tree.tokenTag(last + 1) == .comma) last += 1;
        const start = tree.tokenStart(first);
        const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
        var parser: Parser = .{ .ctx = self.source.ctx, .tokens = try tokenize(self.source.ctx, tree.source[start..end]) };
        try parser.expect(signature);
        return parser;
    }
    pub fn expect(self: Scope, signature: []const u8, body: []const u8) c.Error!void {
        var parser = try self.declaration(signature);
        try parser.expect(body);
        try parser.done();
    }
    pub fn container(self: Scope, signature: []const u8) c.Error!Scope {
        const node = try self.selected(signature);
        _ = try self.declaration(signature);
        return self.containerNode(node);
    }
    pub fn containerNamed(self: Scope, name: []const u8) c.Error!Scope {
        const node = try self.named(name) orelse return self.source.ctx.fail("missing declaration owner", .{});
        return self.containerNode(node);
    }
    fn containerNode(self: Scope, node: std.zig.Ast.Node.Index) c.Error!Scope {
        const decl = self.source.tree.fullVarDecl(node) orelse return self.source.ctx.fail("owner must be a container declaration", .{});
        const init = decl.ast.init_node.unwrap() orelse return self.source.ctx.fail("missing owner initializer", .{});
        return self.containerValue(init);
    }
    pub fn containerValue(self: Scope, init: std.zig.Ast.Node.Index) c.Error!Scope {
        var buffer: [2]std.zig.Ast.Node.Index = undefined;
        try self.source.ctx.require(self.source.tree.fullContainerDecl(&buffer, init) != null, "owner must be a container declaration");
        const child: Scope = .{ .source = self.source, .node = init, .parent = try self.source.ctx.make(Scope, self) };
        try child.unshadowedAliases();
        return child;
    }
    fn unshadowedAliases(self: Scope) c.Error!void {
        var buffer: [2]std.zig.Ast.Node.Index = undefined;
        const owner = self.source.tree.fullContainerDecl(&buffer, self.node) orelse return self.source.ctx.fail("unsupported declaration owner", .{});
        for (owner.ast.members) |member| {
            // Qualified member functions may intentionally share a name with a
            // file-level wrapper. Container aliases must not redirect bindings.
            if (self.source.tree.fullVarDecl(member) == null) continue;
            const name = try self.memberName(member) orelse continue;
            var parent = self.parent;
            var depth: usize = 0;
            while (parent) |ancestor| : (parent = ancestor.parent) {
                depth += 1;
                try self.source.ctx.require(depth <= 128, "source owner nesting limit");
                if (try ancestor.named(name) != null) return self.source.ctx.fail("source declaration shadows ancestor binding: {s}", .{name});
            }
        }
    }
    pub fn unshadowed(self: Scope, names: []const []const u8) c.Error!void {
        for (names) |name| try self.source.ctx.require(try self.named(name) == null, "source dependency is shadowed in owner");
    }
};
/// File-level admission only. Members require an explicit Scope.container path.
pub fn rootDeclaration(ctx: *c.Context, bytes: []const u8, signature: []const u8) c.Error!Parser {
    var declarations = try Declarations.init(ctx, bytes);
    defer declarations.deinit();
    return declarations.root().declaration(signature);
}
pub fn balanced(ctx: *c.Context, tokens: []const Token, start: usize) c.Error!usize {
    return balancedAt(ctx, tokens, start, 0);
}
fn balancedAt(ctx: *c.Context, tokens: []const Token, start: usize, depth: usize) c.Error!usize {
    try ctx.require(depth <= 128, "source group nesting limit");
    try ctx.require(start < tokens.len, "missing source group");
    const close = if (std.mem.eql(u8, tokens[start].text, "{")) "}" else if (std.mem.eql(u8, tokens[start].text, "(")) ")" else if (std.mem.eql(u8, tokens[start].text, "[")) "]" else return ctx.fail("invalid source group", .{});
    var index = start + 1;
    while (index < tokens.len) : (index += 1) {
        const text = tokens[index].text;
        if (std.mem.eql(u8, text, close)) return index;
        if (c.oneOf(text, &.{ "{", "(", "[" })) {
            index = try balancedAt(ctx, tokens, index, depth + 1);
            continue;
        }
        if (c.oneOf(text, &.{ "}", ")", "]" })) return ctx.fail("unbalanced source group", .{});
    }
    return ctx.fail("unterminated source group", .{});
}
pub fn structMember(ctx: *c.Context, bytes: []const u8, owner: []const u8, fields: []const u8, member: []const u8, signature: []const u8) c.Error!Parser {
    var declarations = try Declarations.init(ctx, bytes);
    defer declarations.deinit();
    const scope = try declarations.root().container(owner);
    _ = try scope.declaration(signature);
    var outer = try declarations.root().declaration(owner);
    return memberBody(&outer, fields, member, signature);
}
pub fn memberBody(owner: *Parser, fields: []const u8, name: []const u8, signature: []const u8) c.Error!Parser {
    const ctx = owner.ctx;
    try owner.expect(try ctx.fmt("struct {{ {s}", .{fields}));
    var selected: ?[]const Token = null;
    var depth: usize = 1;
    var parens: usize = 0;
    while (depth > 0) {
        try ctx.require(owner.pos < owner.tokens.len, "unterminated struct owner");
        if (depth == 1 and parens == 0 and owner.pos + 1 < owner.tokens.len and std.mem.eql(u8, owner.tokens[owner.pos + 1].text, ":")) return ctx.fail("unreviewed struct field or typed declaration", .{});
        if (depth == 1 and owner.pos + 2 < owner.tokens.len and std.mem.eql(u8, owner.tokens[owner.pos].text, "pub") and std.mem.eql(u8, owner.tokens[owner.pos + 1].text, "fn") and std.mem.eql(u8, owner.tokens[owner.pos + 2].text, name)) {
            try owner.expect(try ctx.fmt("{s} {{", .{signature}));
            const start = owner.pos;
            const stop = try balanced(ctx, owner.tokens, start - 1);
            try ctx.require(selected == null, "ambiguous struct member");
            selected = owner.tokens[start..stop];
            owner.pos = stop + 1;
        } else {
            const token = try owner.pop();
            if (std.mem.eql(u8, token, "{")) depth += 1 else if (std.mem.eql(u8, token, "}")) depth -= 1;
            if (std.mem.eql(u8, token, "(")) parens += 1 else if (std.mem.eql(u8, token, ")")) {
                try ctx.require(parens > 0, "unbalanced struct member parameters");
                parens -= 1;
            }
        }
    }
    try owner.expect(";");
    return .{ .ctx = ctx, .tokens = selected orelse return ctx.fail("missing struct member", .{}) };
}
pub fn has(ctx: *c.Context, bytes: []const u8, token: []const u8) c.Error!bool {
    for (try tokenize(ctx, bytes)) |item| if (std.mem.eql(u8, item.text, token)) return true;
    return false;
}
pub fn importName(ctx: *c.Context, token: []const u8) c.Error![]const u8 {
    return std.zig.string_literal.parseAlloc(ctx.allocator, token) catch return ctx.fail("nonstatic source import", .{});
}

test "native Zig declaration admission ignores trivia and rejects ambiguous names" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: c.Context = .{ .allocator = arena.allocator() };
    var parser = try rootDeclaration(&ctx, "// const x = 7;\nconst x = 1;", "const x =");
    try parser.expect("1;");
    try parser.done();
    try std.testing.expectError(error.InvalidInput, rootDeclaration(&ctx, "const x = 1; const x = 2;", "const x ="));
}
