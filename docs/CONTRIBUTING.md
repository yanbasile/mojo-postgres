# Contributing to Mojo-Postgres

Thank you for your interest! We welcome contributions of all kinds.

## Getting Started

1. **Fork the repository**
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/mojo-postgres.git`
3. **Create a branch**: `git checkout -b feature/uuid-type-handler`
4. **Make changes & test**
5. **Submit a pull request**

## Development Setup
```bash
# Install Mojo (24.5 or later)
curl -s https://get.modular.com | sh -
modular install mojo

# Clone repository
git clone https://github.com/yanbasile/mojo-postgres.git
cd mojo-postgres

# Start PostgreSQL test database (coming soon)
docker-compose up -d

# Run tests (coming soon)
mojo test tests/
```

## Type Handler Implementation Guide

Each PostgreSQL type needs a handler implementing:

1. **Binary encoding** (Mojo → PostgreSQL wire format)
2. **Binary decoding** (PostgreSQL wire format → Mojo)
3. **Text encoding** (Mojo → String)
4. **Text decoding** (String → Mojo)
5. **Unit tests** (minimum 10 test cases)

### Template
```mojo
from collections import DynamicVector

struct YourTypeHandler:
    """Handler for PostgreSQL YOUR_TYPE.
    
    OID: XXX
    Size: N bytes (or variable)
    Format: [Description]
    """
    
    alias OID: Int = XXX  # From pg_type.dat
    
    @staticmethod
    fn encode_binary(value: YourMojoType) -> DynamicVector[UInt8]:
        """Encode to PostgreSQL binary format (network byte order)."""
        var buffer = DynamicVector[UInt8]()
        # Implementation here
        return buffer
    
    @staticmethod
    fn decode_binary(data: DynamicVector[UInt8]) -> YourMojoType:
        """Decode from PostgreSQL binary format."""
        # Implementation here
        pass
    
    @staticmethod
    fn encode_text(value: YourMojoType) -> String:
        """Encode to text format (for simple query protocol)."""
        # Implementation here
        pass
    
    @staticmethod
    fn decode_text(text: String) -> YourMojoType:
        """Decode from text format."""
        # Implementation here
        pass

# Tests
fn test_your_type_roundtrip():
    var original: YourMojoType = ...
    var encoded = YourTypeHandler.encode_binary(original)
    var decoded = YourTypeHandler.decode_binary(encoded)
    assert_equal(decoded, original)
```

### Testing Checklist

- [ ] Positive values
- [ ] Negative values (if applicable)
- [ ] Zero
- [ ] NULL handling
- [ ] Min/max bounds
- [ ] Edge cases
- [ ] Binary roundtrip
- [ ] Text roundtrip
- [ ] Integration test with real PostgreSQL

## Code Style

- **Naming**: snake_case for functions/variables, PascalCase for structs
- **Documentation**: All public APIs need docstrings
- **Comments**: Explain *why*, not *what*
- **Testing**: Every function needs tests
- **Error Handling**: Use Result types, not exceptions where possible

## Pull Request Process

1. **Update tests**: Add tests for your changes
2. **Update docs**: Document new features
3. **Run tests**: Ensure all tests pass
4. **Format code**: Follow Mojo style guidelines
5. **Write clear commit messages**: "Add UUID type handler (#73)"

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature (type handler, protocol feature)
- [ ] Documentation update
- [ ] Performance improvement

## Related Issues
Closes #XX

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Tested against PostgreSQL 12, 13, 14, 15, 16

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests pass locally
- [ ] No breaking changes (or documented)
```

## Community

- **GitHub Discussions**: Ask questions, share ideas
- **Issues**: Bug reports, feature requests
- **Discord**: (coming soon)

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Given credit in documentation

## Resources

- [PostgreSQL Protocol Documentation](https://www.postgresql.org/docs/current/protocol.html)
- [PostgreSQL Type OIDs](https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat)
- [Mojo Language Guide](https://docs.modular.com/mojo/)
- [Mojo Standard Library](https://docs.modular.com/mojo/lib/)

Thank you for making mojo-postgres better! 🔥
