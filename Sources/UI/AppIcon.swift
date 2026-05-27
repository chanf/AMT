import SwiftUI

struct AppIcon: View {
    var size: CGFloat = 128
    
    var body: some View {
        ZStack {
            // macOS Big Sur style squircle background
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.24, green: 0.86, blue: 0.52), Color(red: 0.2, green: 0.7, blue: 0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: size * 0.05, x: 0, y: size * 0.02)
            
            // Central Folder Icon
            Image(systemName: "folder.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.1), radius: size * 0.02, x: 0, y: size * 0.01)
            
            // Small Device indicator (metaphor for Android)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: size * 0.35, height: size * 0.35)
                            .shadow(radius: size * 0.02)
                        
                        Image(systemName: "phone.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size * 0.2)
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.42))
                    }
                    .offset(x: size * 0.05, y: size * 0.05)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            AppIcon(size: 128)
            AppIcon(size: 512)
        }
        .padding()
    }
}
