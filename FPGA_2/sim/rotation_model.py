import numpy as np
from PIL import Image, ImageDraw

def generate_parabola_points(width=320, height=180):
    points = []
    a = 0.005
    step = width // 20
    
    for x in range(-width//2, width//2, step):
        y = int(a * (x * x))
        if 0 <= x + width//2 < width and 0 <= y < height:
            points.append((x + width//2, height - y - 1, 160))
    
    return np.array(points)


def rotate_points_y_centered(points, angle_degrees):
    theta = np.radians(angle_degrees)
    center = np.array([160, 0, 160])
    
    rotation_matrix = np.array([
        [np.cos(theta),  0, np.sin(theta)],
        [0,              1, 0           ],
        [-np.sin(theta), 0, np.cos(theta)]
    ])
    
    points = np.array(points)
    centered = points - center
    rotated = np.dot(centered, rotation_matrix.T)
    result = rotated + center
    
    return np.clip(result, [0, 0, 0], [320, 180, 320])

def draw_points(points, filename):
    img = Image.new('RGB', (320, 180), color='black')
    draw = ImageDraw.Draw(img)
    for x, y, z in points:
        z = max(z, 1)  
        # px = int((x * 160) / (50 + z)) 
        # py = int((y * 160) / (50 + z))
        # draw.ellipse([px-2, py-2, px+2, py+2], fill='white')
        draw.ellipse([x-2, y-2, x+2, y+2], fill='white')
    img.save(filename)

points = generate_parabola_points()
draw_points(points, 'original.png')
rotated = rotate_points_y_centered(points, 45)
draw_points(rotated, 'rotated.png')