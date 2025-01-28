import SwiftUI

struct ContentView: View {
    @State private var showSplashScreen = true

    var body: some View {
        ZStack {
            if showSplashScreen {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSplashScreen = false
                            }
                        }
                    }
            } else {
                TimezoneInputViewController()
            }
        }
    }
}

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var logoRotation: Double = 360
    @State private var clockOffset: CGFloat = -10

    var body: some View {
        ZStack {
            Color(red: 0.6, green: 0.8, blue: 1.0).ignoresSafeArea()
            
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 150, height: 150)
                    
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .offset(x: clockOffset)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: clockOffset)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .rotationEffect(.degrees(logoRotation))
                
                Text("TimeSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                logoScale = 1.0
                logoOpacity = 1.0
                logoRotation = 0
            }
            clockOffset = 10
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


