{
  description = "Development environment for a Jekyll blog on GitHub Pages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShell.${system} = pkgs.mkShell {
        name = "jekyll-env";

        buildInputs = with pkgs; [
          ruby           # Ruby language
          bundler        # Ruby Bundler for dependency management
          nodejs         # Node.js for JavaScript runtime (required by some Jekyll themes/plugins)
          yarn           # Yarn package manager for managing JS dependencies
          gh
          git            # Git for version control
          openssl        # OpenSSL for secure communication
          libffi         # Library for foreign function interfaces (needed for some gems)
          zlib           # Compression library (required by some gems)
          gnumake        # Build tool (replaces 'make')
          gcc            # C compiler (needed for native extensions)
        ];

        shellHook = ''
          echo "Welcome to the Jekyll development environment!"
          echo "Run 'bundle install' to set up your Ruby dependencies."
        '';
      };
    };
}

